# Game State & Stage Flow

> **Status**: Approved (lean design re-review 2026-11-04; 4 recommended items in the review log)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-01 — CONCERNS applied (call-early cost restated, always-call bot gate, button arming and test coverage, leaks per lane cut). User kept call-early and focus freeze in MVP.
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-04
> **Last Verified**: 2026-11-02
> **Implements Pillar**: Enabling system for all four pillars; Pillar 3 most directly (a new stage gets time to be read, and a lost stage retries at once)

## Summary

Boots the app, holds the catalogue, runs each battle through Build, Wave and Intermission, owns lives, and decides Won or Lost. Players feel it as pacing: time to read a new path, and a timer they can beat by calling the next wave early for bonus gold. Retry rebuilds the whole battle, and a battle can run with no scene or real time, which is how bots and tests measure the game.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Data & Config Pipeline`

## Overview

Game State & Stage Flow is what makes a stage begin, advance and end. It boots the app, holds the loaded catalogue, starts each battle, connects the other battle systems to each other, owns the player's lives, and decides when a stage is won or lost. Players meet it as pacing: a stage waits while they read the path, then waves come on a timer they can beat by calling the next wave early for bonus gold, which shortens the burst's recovery. Calling is a fast-forward for a player who is ready, not a risk: the field is clear between waves, so it costs only the time the wait would have given, and bot gates bound what it can earn. A lost stage retries at once with nothing carried over. It exists so that no other system needs to know about any other, and so a whole battle can run with no scene, no renderer and no real time, which is how the bots and tests measure the game. It owns phases and lives, not enemies, gold or towers.

## Detailed Design

### Core Rules

**Roots.**

1. **App root.** The main scene is a minimal root with no gameplay references and no autoload. It triggers the catalogue load, holds the Ready catalogue for the whole session and owns the fatal screen. Because it exists before the load, a catalogue failure has somewhere to go. The only things that survive a retry are this root and the catalogue.
2. **Battle builder.** A plain builder, `build(catalogue, stage_id, seed, fatal_handler)`, constructs one battle and connects its systems in one function of explicit signal connections, so the parser catches a misspelt name. It needs no scene, so bots and tests call it directly. This amends the technical director's note, which named the battle scene script: a scene-owned root cannot run headless. A thin scene wrapper adds the tick loop, the input adapter and the views, and holds no gameplay logic. If the stage cannot be built, such as a null Stage record, `build` calls `fatal_handler` and returns null; the handler needs no battle to work.
2a. **The battle holds its helpers.** The battle keeps a strong typed field for every helper `build` creates: each system, the failure latch and the accessor, of which there is one per battle, so its failure handler never outlives its battle. The builder holds nothing. The battle exposes what the wrapper's input objects and HUD need and the builder alone reads: the hand, the Hero's and Burst's IDs, `dt` and `to_ticks`. A method Callable or a signal connection does not keep a `RefCounted` target alive, and `.call()` on a dead one raises a script error and aborts the caller (observed on the 4.7.2 desktop editor; export and phone unverified, ADR-0001). A lambda that captures its target does keep it alive (same probe), and `bind()` is unprobed, so injected callables are plain method Callables only, which code review checks.
3. **No god object.** The stage flow and lives live in a pure object. The builder only wires, and a branch on a gameplay value inside it or the wrapper is a defect. Not owned here: gold, the enemy roster, wave contents and durations, spawn timing, stars, saves, gesture rules, screen layout, or what happens inside any system's tick.

**Time.**

4. **One way in.** Simulation time enters only through `battle.tick(dt)`. Gameplay systems use no `_process`, engine timers, `await`, wall clock or physics areas, only countdowns and distance checks. Humans and bots run the same fixed tick (60 per second proposed, matching the Data & Config interval floor); the wrapper accumulates real time and clamps a long frame. Prototype numbers came from variable time for humans and 1/30 for bots, so they do not transfer and bots must be re-baselined. Authored durations become whole ticks through one conversion, `to_ticks` (Enemy & Wave GDD), since a repeated float countdown drifts: 5.0 s took 301 ticks.
5. **Fixed order, commands between ticks.** Systems tick in a fixed order, each owning GDD agreeing its place. Player and bot commands apply only between ticks, never during one. Randomness uses the injected seed: the same stage, seed and command script give an identical result.

**Stage phases.**

6. **Build.** A stage opens in Build with its clock stopped, so the player can read the new path. Wave 1 starts only when the player taps Start Wave. There is no timer here. No `phase_changed` signal announces the opening, so a view reads `phase()` when it is built.
7. **Wave.** A wave runs until Enemy & Wave reports `wave_cleared`, meaning all its groups have spawned and every enemy, including any it spawned, has died or leaked. The last wave reports `waves_completed` instead, so Flow needs no wave count.
8. **Intermission.** After every wave but the last, a countdown runs. Enemy & Wave owns its duration and sends it as the payload of `wave_cleared`. The simulation keeps ticking, so the burst keeps recovering. When it reaches 0 the next wave starts.
9. **Call early is a fast-forward (user decision, 2026-11-04).** During Intermission the same button starts the next wave at once. Flow emits `wave_called_early(seconds_left)`, and the Tower GDD turns that into bonus gold. Its job is to let a ready player skip the wait, and it is not a risk decision. Calling costs only what the remaining seconds would have given: burst recovery while the burst is cooling, and time to re-pin and build. Once the burst is Ready that cost is small, and a player who ignores the hero pays none of the burst part; that is accepted. The bonus must never depend on burst state, which would turn the hero into an economy timer. A wave cannot be called while another is running at MVP. Two gates bound it (Deferred criteria): on every mixed build, a driven hero calling the moment the burst is Ready ends within 2 lives of never calling; and a won stage with every wave called still runs at least 3.5 minutes (proposed: about two thirds of the uncalled stage, so calling saves at most a third). Bots also report whether a mono-role build that calls ties the best mixed build, as single only does today, and human logs decide whether that matters (Tower Rule 16; Hero, Deferred criteria). The concept's 5 to 8 minutes is for stages of 8 to 12 waves, not MVP's 6. On those 6 and on mixed builds, throwaway bots show 5.0 to 5.3 minutes without calling, 4.0 to 4.2 calling when Ready, and 3.6 to 3.8 always calling, with no mixed build's lives changing. Bots do not call early unless a mode says so, and a **towers-only, always-call** mode stays in the Pillar 2 bot gates, since a call must not turn a loss into a win.
10. **Actions are never phase-locked.** Building, upgrading and re-pinning stay live in Build, Wave and Intermission, and a change of phase never cancels a gesture. In Build, towers apply at once and a pin places the hero at its point at once (Hero Rule 2; user decision, 2026-11-04), so the first drag visibly works while the clock is stopped; timers begin on the first tick. The burst is the exception: Hero refuses it in Build, since a stopped clock would never let it recover. Paused is not a phase these run in: its modal Control stops every press (Battle HUD Rule 2), so no system checks for Paused, and Flow's own commands do nothing there. Hero's and Tower's commands do not check, so a direct `pin` while Paused from Build would place the hero; headless has no lifecycle signal, so only a test that pauses by hand could do that, and none should.

**Lives and outcome.**

11. **Lives.** Flow owns lives, starting at the stage's `starting_lives`. On `enemy_leaked(lives_cost)` it applies the lives formula and, if lives changed, emits `lives_changed(current)`.
12. **Lost.** The first leak that takes lives to 0 ends the stage on that tick, as Lost.
13. **Won.** Enemy & Wave's `waves_completed` means every group of every wave has spawned and every enemy has died or leaked. It is the whole win test, because Flow keeps no enemy count that could disagree with the roster. Enemy & Wave must emit leak events synchronously and before `waves_completed`.
14. **A tie is a loss.** Under Combat's tick order leaks resolve before fire, so a fatal leak ends the tick before any kill. If `waves_completed` still arrives after that, the stage stays Lost and the event is ignored. This is a defensive guard: Enemy & Wave's fatal leak skips the clear, so the event should not arrive.
15. **One order, and the outcome latches.** Every transition commits its state, then acts (starts the wave, or stops the clock and cancels input), then emits in the order the criteria log. Flow checks the Fatal latch after acting and after each emit, and makes no further emit once it is set; delivery of the emit already under way still reaches its remaining listeners, since a signal cannot be stopped part way. So a listener always reads the new state, including `wave_index()` after `phase_changed(Wave)`. `phase_changed` fires on every state change and names the new phase. Changes among Build, Wave and Intermission, and a resume, emit it without stopping the clock or cancelling input; Won, Lost, Paused and Fatal stop the clock and cancel input before they emit. The stage logic is a pure object, so it cancels through an injected `cancel_input()`, a public method on the battle that does nothing when the wrapper has not set a cancel through `set_input_cancel`, as headless, or when its target is gone; on retry the app root calls the same method. An outcome or Fatal committed mid-tick makes the remaining systems skip that tick, so nothing changes the result afterwards. The battle exposes `in_build()`, which Hero uses to refuse the burst and to place a pin, true in Build and while Paused from Build, and one `halted()`, true on Won, Lost and Fatal, for systems whose own loops must stop. `halted()` does not mean Fatal: a view that must tell them apart tests `phase() == FATAL`. Won and Lost are terminal for gameplay, so later ticks, events and commands do nothing, and only Fatal can replace them (Rule 18). The result stays readable after the outcome: outcome, last wave started (Enemy & Wave's `wave_index()`, injected by the builder, so Flow still keeps no wave count), lives left and Combat's damage by source, shown as plain text at MVP.
15a. **Events out of phase.** A `wave_cleared` or `waves_completed` in the wrong phase, or an `enemy_leaked` in Build, Paused or after an outcome, is a contract breach by Enemy & Wave: development builds log an error and the event is ignored. An `enemy_leaked` in Intermission also logs an error but still applies, because losing a life must never be silently dropped.

**Retry.**

16. **Rebuild, never reset.** Retry destroys the whole battle and builds a new one; no system has a reset function. The prototype's hand-listed reset of 22 fields is exactly how state leaks between attempts. The Retry button only sets a latch on the app root, whose frame acts on it, Fatal first. The order is: stop the clock, call the old battle's `cancel_input()`, remove the old wrapper at once and drop the battle, build the new one. `queue_free` leaves the old battle alive to the frame's end and `remove_child` plus `free()` does not (observed, 4.7.2 desktop); ADR-0001 names the call, and Rule 18 uses the same one. It happens between ticks, never inside a signal. The input resolver and adapter are rebuilt too, because their registrations belong to dying owners. A retried battle opens in Build. The path's draw-in is deferred past MVP, and when it arrives a retry skips it.

**Pause.**

17. **Focus loss freezes.** There is no pause button at MVP. Losing focus or backgrounding the app enters Paused on desktop and phone alike, so the path is proven before the first phone build. These two alone fire the adapter's `lifecycle_paused`; a viewport resize cancels input but does not pause (Input Rule 7). The clock stops, so `battle.tick` returns at once, and input cancels. Paused never ends by itself: a tap resumes and reaches nothing beneath, with no countdown. The tick accumulator is zeroed, so no time jump follows, and a finger down across the pause stays dead until lifted. Pausing a terminal state does nothing. On desktop the click that refocuses the window may also be the resume tap; ADR-0003 checks, and either is acceptable. An app killed by the OS loses the stage, since nothing is saved at MVP. There is no quit button.

**Fatal.**

18. **Fatal latches and halts.** The failure handler is idempotent and keeps the first cause. It sets a latch on the battle and on the app root, stops ticks and skips the remaining systems in the current tick. **Fatal overrides** Won, Lost and Paused, because nothing is saved at MVP and replacing a result screen costs nothing (creative director's ruling, 2026-11-04; revisit when saves arrive). If it fires during `build`, the root discards the partial battle without ticking it. If it fires while the wrapper is assembling, the wrapper checks the latch after each step and stops. After Fatal, the root removes and frees the wrapper with Rule 16's call on its next frame, then drops the battle, then shows the screen. Once the latch is set, Flow's commands do nothing, and Tower's and Hero's return `HALTED`. GDScript has no exceptions, so the calling function still finishes on a garbage value: therefore, once Fatal is set, nothing persists and no other transition is legal. A failed catalogue load, a bad accessor call, a stage scene that fails to load or instantiate (the wrapper checks for null) and a resolver `create` that returns null in the wrapper all take this one path to the generic screen, which uses no catalogue data. A scene whose script is broken still loads, and is not caught: the scene holds only the look, so it shows up on the first run.

**Wiring is tested, not trusted.** An unconnected signal is a silent bug, so one test fails if any signal of any battle system has no listener, unless it is on a named allowlist for views, and a scripted micro-battle proves the targets are right: a kill raises gold by the bounty, a leak drops lives, and clearing all waves wins.

**Handed to owning GDDs.**
- **Enemy & Wave:** `wave_cleared`, `waves_completed`, `enemy_leaked(lives_cost)`, the leak-before-complete order, keeping spawned children on the roster atomically so a wave cannot clear early, the `intermission_duration` field on the Wave record, a cap on `start_delay` (a wave cannot be called early, so a long one is an empty field), and its place in the tick order. Leaks per lane are cut until a map has more than one lane.
- **Hero:** refuses the burst in Build, and balances burst cooldown against `intermission_duration` with Enemy & Wave.
- **Tower:** the early-call bonus value, priced knowing that a ready burst makes calling nearly free, and never dependent on burst state, and one direct build command shared by the arc and the bots, since the arc lives in the HUD and is absent headless. Input's Rule 11 has bots call Hero's and Tower's commands directly.
- **Combat:** per-source damage counters readable after the outcome.
- **Battle HUD:** the Start/Call button, the outcome screen and the resume tap. Input's adapter gains a lifecycle signal for Flow.

**Deliberately not built for MVP.** Menus and stage select, saves, stars, grades, a report screen, game speed-up, calling a wave during a wave, a manual pause, a quit button, Retry on the Paused screen (user decision, 2026-11-04), in-place reset, an event-bus autoload, a dependency-injection container, a state-machine framework, a scene stack and replays.

→ Becomes ADR-0001 (App Lifecycle, Composition Root and Fatal Path), with ADR-0004 for the clock: tick rate, order and clamp; the battle's ownership of its helpers; retry teardown including views; the pause mechanism; which lifecycle notifications fire on each platform; guaranteeing the fatal scene loads; the main scene. **None of this is in the pinned engine reference, so every engine behaviour is unverified until that ADR checks live 4.7 docs and a phone run.**

### States and Transitions

**App machine.** Menus can arrive at Vertical Slice without touching stage logic.

| State | Meaning | Transitions |
|---|---|---|
| Boot | App root loading the catalogue | Ready → InStage. Failed → Fatal |
| InStage | One battle exists | Failure handler → Fatal. Retry stays in InStage with a new battle |
| Fatal | Generic screen; ticks stopped | None: absorbing |

**Stage machine**, one per battle. Paused remembers the phase it left.

| State | Clock | Transitions |
|---|---|---|
| Build | Stopped | Start Wave → Wave 1. Focus loss → Paused |
| Wave | Running | `wave_cleared` → Intermission. `waves_completed` → Won. Lives 0 → Lost. Focus loss → Paused |
| Intermission | Running | Countdown 0 or call early → next Wave. Lives 0 → Lost (a contract breach, Rule 15a). Focus loss → Paused |
| Paused | Stopped | Resume tap → the phase it left |
| Won | Stopped, latched | Retry → new battle |
| Lost | Stopped, latched | Retry → new battle |
| Fatal | Stopped, latched | None: absorbing |

**From every state above**, Won, Lost and Paused included, the failure handler → Fatal (Rule 18).

### Interactions with Other Systems

| System | Direction | Interface | Owner |
|---|---|---|---|
| Data & Config Pipeline | reads | App root triggers load and holds the catalogue; reads the Stage record; receives the failure handler's calls | Data (load, lookup); this system (root, screen) |
| Input & Gesture Resolver | builds | Wrapper builds resolver and adapter per battle; Won, Lost, Paused, Fatal and retry call `cancel()`; adapter forwards `lifecycle_paused` (Input Rule 7) | Input (API); this system (composition) |
| Enemy & Wave | wires, commands | Listens to `wave_cleared`, `waves_completed`, `enemy_leaked`; calls start next wave; reads `wave_index()` for the result | Enemy & Wave (signals) |
| Tower System | wires | Forwards `wave_called_early(seconds_left)`; connects kills to gold | Tower (bonus value) |
| Hero System | wires | Builds and ticks it; injects `halted()` and `in_build()`; reads `left_handed` from Data's Input record and the one Hero record's ID and `burst_id`, passing the IDs and the hand to HeroSim and the wrapper's HeroInput, and the hand and the Burst's ID to the HUD for the wedge (Hero Rules 2, 8; Battle HUD Rule 12) | Hero |
| Combat & Damage | wires, reads | Reads per-source counters for the result | Combat |
| Battle HUD | listens | `lives_changed`, `phase_changed`; reads `phase()`, lives, `in_build()`, `intermission_left`, result; sends Start/Call, Retry, resume | HUD (drawing, button placement) |
| Bots and tests | call | `build`, `tick`, commands, read result; timeouts belong to the harness | Harness |

## Formulas

The **lives_after** formula is defined as:

`lives_after = max(0, lives_before − lives_cost)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `lives_before` | int | 1–1,000 | calculated | Lives before this leak; starts at `starting_lives` |
| `lives_cost` | int | 0–1,000 | data file (Enemy record) | Lives this enemy costs on leaking |
| `lives_after` | int | 0–1,000 | calculated | Clamped, never negative |

**Output Range:** 0 at a cost of at least the lives left, which is Lost; 1,000 at most. A cost of 0 changes nothing but still resolves the enemy.
**Example:** 3 lives, cost 5: `max(0, 3 − 5)` = 0, Lost.

The **intermission_left** formula is defined as:

`intermission_left = max(0, intermission_left − 1)`, in whole ticks, starting at `to_ticks(intermission_duration)`; `seconds_left = intermission_left × dt`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| `intermission_left` | int, ticks | 0–36,000 | calculated, from the `wave_cleared` payload (Wave record) | Time before the next wave |
| `dt` | float, seconds | 1/60 proposed | constant | The fixed tick; an engine constant, not a catalogue value |

Flow ticks before Enemy & Wave, and the tick that enters Intermission does not decrement.

**Output Range:** the next wave starts on the tick it reaches 0. A duration of 0 starts it on the next tick. `seconds_left` on an early call is this value, above 0 up to the full duration; a call at 0 is ignored with no signal.
**Example:** 720 ticks left, player calls: `wave_called_early(12.0)`. The next wave commits at once and its members spawn from the next tick (Enemy & Wave Rule 7).

`seconds_left` counts every tick left, while the called wave's members still spawn on the next tick, so a call pays for one tick more than it saves. Tower Rule 16 prices that.

Data's validator rejects a negative or non-finite `lives_cost` or `intermission_duration` at load (Data Rule 7), so Flow does not guard them; a code-built fixture passing one is a test bug.

The bonus for calling early is the Tower GDD's formula, not this one.

## Edge Cases

- **If the last kill and the fatal leak land on one tick**: Lost (Rule 14).
- **If several leaks land on one tick and the first reaches 0**: Lost on that leak; the rest are ignored.
- **If `lives_cost` is 0**: lives are unchanged and `lives_changed` is not emitted; the enemy still resolves.
- **If every enemy in a real stage has a `lives_cost` of 0**: the stage cannot be lost. The CI content test rejects it (Enemy & Wave owns the check); code-built fixtures may do it, so the catalogue validator does not.
- **If `starting_lives` is 1**: the first costly leak is Lost.
- **If the result is read after a loss**: "wave reached" is the last wave started, which is `wave_index()`.
- **If a call-early command and the countdown's expiry fall together**: commands apply between ticks, so whichever comes first starts the wave, and the other finds no Intermission and is ignored. `wave_called_early` fires only for a real call.
- **If Start Wave is tapped twice**: the second tap finds no Build and is ignored.
- **If the last wave clears**: `waves_completed` applies; there is no Intermission and the button is gone.
- **If focus is lost in Won, Lost or Fatal**: no state change.
- **If the failure handler fires in Won, Lost or Paused**: Fatal replaces the screen (Rule 18). A bad read while the HUD builds its result can do this.
- **If a stage is doomed**: the only way out is to lose it, or relaunch. Retry on the Paused screen is deferred (user decision, 2026-11-04), since Paused comes only from focus loss.
- **If a listener fires the failure handler during an emit**: the handler emits `phase_changed(Fatal)` at once and Flow makes no further emit for that transition. Listeners still due the emit under way receive it, and one that must not act tests `phase() == FATAL`.
- **If `build` cannot find its stage**: the handler fires, `build` returns null and there is no battle to discard.
- **If focus is lost and the OS kills the app**: the stage is lost and the next launch boots cold.
- **If a finger is held across a retry**: the new adapter never saw its press, so its moves are dropped and it must lift first.
- **If Retry arrives outside Won or Lost**: ignored. Paused is not stuck, because a tap exits it.
- **If Retry is tapped twice**: one rebuild; the second tap belongs to a destroyed button or is a new press in Build, where it reaches whatever is beneath.
- **If a press began before the outcome screen armed**: it does not count as a Retry tap (Game Feel).
- **If a bad accessor call happens mid-tick**: Fatal latches, the remaining systems skip that tick, and the calling function finishes on a value nothing persists.
- **If the failure handler fires twice**: the first cause is kept.
- **If a stage scene fails to load or instantiate**: Fatal at stage start; the catalogue stays Ready, though there is no way out at MVP but relaunching.
- **If a press began before Paused**: it never resumes, and stays dead until lifted.
- **If the handler fires during `build`**: the partial battle is discarded unticked, and Fatal shows.
- **If a long frame hits (app hitch)**: the wrapper clamps the ticks owed, so the game slows rather than jumping. The clamp value belongs to ADR-0004.

## Dependencies

**Upstream (hard):** Data & Config Pipeline, for load, the failure path and the Stage record. Input & Gesture Resolver, whose resolver and adapter the wrapper builds per battle, cancelled on outcome, pause, fatal and retry, with a forwarded lifecycle signal. Combat & Damage, for `tick_status` and per-source counters readable after the outcome.

**Downstream (hard; each MVP system has its own GDD):**

| System | Interface |
|---|---|
| Enemy & Wave | Emits the wave signals; owns durations; defines `to_ticks` |
| Tower System | Early-call bonus; kills to gold; direct build command |
| Hero System | Built and ticked here; receives `halted()`, `in_build()` (burst refusal and the instant pin), the hand and the Hero's and Burst's IDs |
| Battle HUD & Build UI | Draws phases, lives, countdown, result; sends commands |
| Stage Progression & Stars (VS) | Reads the result (soft at MVP) |
| Save/Load, Menu & Screen Flow (VS) | Join the app machine (soft at MVP) |

Per the bidirectional rule, each of these must list this one. The MVP GDDs do, and the Vertical Slice ones must when authored.

## Visual/Audio Requirements

This system draws nothing but the fatal screen, and every other visual is triggered by its signals, per `design/art/art-bible.md` §2:

| Event | Visual (owner) | Art bible |
|---|---|---|
| Stage opens | Path draw-in, deferred past MVP (Enemy & Wave, Battle HUD): the path is simply there | §2 Build |
| Lost | Hero dims to an outline; retry is the only filled shape (HUD, Hero) | §2 Defeat |
| Won | Tower bodies brighten in sequence, deferred past MVP; a compact panel leaves the board in view (HUD) | §2 Victory |
| Fatal | Generic text on the field colour, no catalogue data (this system) | — |

Audio: none at MVP.

## Game Feel

All durations are proposed, untested and presentation only, so the wrapper runs them outside the simulation.

- **Lost is immediate.** The simulation freezes on the tick lives reach 0, in-flight drags cancel without firing, and the screen appears about 0.4 s later.
- **Won gets a short beat.** Input is dead for about 0.4 s, then the screen appears. A longer beat waits for the brighten sequence, since a still screen for 1 s can read as a hang.
- **Retry is one tap, no confirm.** The button arms about 0.3 s after appearing and ignores presses begun earlier, so a thumb already down cannot fire it.
- **Start/Call arms the same way.** It appears when a wave clears, possibly under a thumb, and it is irreversible.
- **Calling early shows both sides.** The button shows the bonus and the time left, with burst readiness beside it, in plain numbers and shapes.
- **Starting a stage is never rushed.** Build has no timer.
- **The result shows numbers without ranking.** Hero share is a balance metric, not a goal (Pillar 2), so it is not highlighted.

## UI Requirements

None owned except the fatal screen. Battle HUD owns the Start/Call button, the countdown, lives, the outcome screen and the resume tap. A lost stage shows "Broke on wave N of 6"; Won and Lost both show damage by source.

The Start/Call button is irreversible, so it must stay clear of the burst corner and of build slots. Art bible §7 now allows it in the bottom band in Build and Intermission only, when the lower lane is empty. It registers as an Input target, since it sits in the field rather than the top band.

## Cross-References

| This Document References | Target | Specific Element | Nature |
|---|---|---|---|
| Load, failure handler, Stage record, interval floor | `design/gdd/data-config-pipeline.md` | Rules 5, 8, 9, 10, 12; field domains | Rule dependency |
| Adapter contract, `cancel()`, bots on direct commands | `design/gdd/input-gesture-resolver.md` | Rules 7, 11; Dependencies | Rule dependency |
| `to_ticks`, wave signals, `wave_index()`, leak order | `design/gdd/enemy-wave.md` | Rules 7, 10, 11, 13, 14; Formulas | Rule dependency |
| Tick order, per-source counters | `design/gdd/combat-damage.md` | Rules 5, 11 | Rule dependency |
| Early-call bonus, chip closing on `phase_changed`, build command | `design/gdd/tower-system.md` | Rules 5, 8, 16 | Ownership handoff |
| Burst refused in Build, pin placed at once in Build, the hand and IDs passed | `design/gdd/hero-system.md` | Rules 2, 6, 8 | Ownership handoff |
| Start/Call, result, resume, retry latch | `design/gdd/battle-hud.md` | Rules 10, 11, 15, 17, 18 | Ownership handoff |
| Composition root | `design/gdd/systems-index.md` | Core Layer TD note | Amended here |
| Between-waves loop, MVP win/lose, retry | `design/gdd/game-concept.md` | Core Loop, Flow State, MVP | Rule dependency |
| Mood per state, panel placement | `design/art/art-bible.md` | §2, §7 | Ownership handoff |
| Reset and timing evidence | `prototypes/hero-pin-concept/main.gd` | `_start`, `_step`, `_run_bots` | Evidence |

## Acceptance Criteria

A recording fake logs every Flow signal. The log is cleared when GIVEN ends, and each THEN is the entire log; anything unlisted fails. A factory builds `stage(lives = 3)`: 3 waves, intermission 1.0 s, `dt` 0.25 (binary-exact). A fake Enemy & Wave `E` counts wave starts, emits on command and returns a settable `wave_index()`. `cancels` counts `cancel_input()` calls. A `phase_changed` listener records `cancels`, `phase()`, `halted()` and `wave_index()` at emit. An error-sink fake counts development errors. Recording systems A, B and C tick from a list passed to the battle's test constructor (seam proposed; ADR-0007 settles it). No scene, no random seeds, no time assertions.

**CI: Logic**
1. (Rule 6) **GIVEN** a new flow, **THEN** `phase()` is Build; **WHEN** 100 ticks, **THEN** an empty log and 0 starts; **WHEN** Start twice, **THEN** `phase_changed(Wave)` and 1 start.
2. (Rules 7, 8, 15) **GIVEN** wave 1, **WHEN** `wave_cleared(1.0)` and 3 ticks, **THEN** `phase_changed(Intermission)` and 1 start; a 4th tick appends `phase_changed(Wave)`, and 2 starts, with the listener reading the raised `wave_index()` at that emit.
3. (Rule 9) **GIVEN** Intermission after 2 ticks, **WHEN** call twice, **THEN** `wave_called_early(0.5), phase_changed(Wave)`, and 2 starts.
4. (Rule 9) **GIVEN** Build, any Wave, or just after expiry, **WHEN** call, **THEN** an empty log and starts unchanged.
5. (Rule 13) **GIVEN** the last wave, **WHEN** `waves_completed`, **THEN** `phase_changed(Won)`.
6. (Rules 11, 12) **GIVEN** a fresh Wave with 3 lives, each of: cost 2 gives `lives_changed(1)`; cost 3 gives `lives_changed(0), phase_changed(Lost)`; cost 5 gives the same; costs 2 then 1 give `lives_changed(1), lives_changed(0), phase_changed(Lost)`; cost 0 gives an empty log, 3 lives and Wave; a fatal leak then a further leak on one tick gives the same log as the fatal leak alone, and 1 sink entry (Rule 15a).
7. (Rule 14) **GIVEN** `stage(1)` in Wave, **WHEN** a leak of cost 1 then `waves_completed`, **THEN** `lives_changed(0), phase_changed(Lost)`.
8. (Rule 15) **GIVEN** Won or Lost, **WHEN** ticks, each of `wave_cleared`, `waves_completed` and `enemy_leaked`, Start, call, resume and focus loss, **THEN** an empty log and the result unchanged. Retry is the root's latch, under Retry below; the failure handler is criterion 13.
9. (Rules 15, 18) **WHEN** B's tick triggers each of Lost, Won and Fatal, **THEN** that tick A 1, B 1, C 0, and a further tick changes no count.
10. (Rules 7, 10, 15) **GIVEN** each of Start, expiry, call and `wave_cleared`, **THEN** `cancels` is 0 and `phase_changed` names the new phase. **GIVEN** a resume, **THEN** `cancels` is unchanged.
11. (Rule 15a) **GIVEN** each of `wave_cleared(1.0)` and `waves_completed` in Build, Intermission and Paused, and `enemy_leaked(2)` in Build and Paused, **THEN** an empty log, phase and lives unchanged, and 1 sink entry. **GIVEN** Intermission with 3 lives, **WHEN** `enemy_leaked(2)`, **THEN** `lives_changed(1)` and 1 sink entry. **GIVEN** Intermission with `stage(1)`, **WHEN** `enemy_leaked(1)`, **THEN** `lives_changed(0), phase_changed(Lost)` and 1 sink entry.
12. (Rule 17) **GIVEN** each live phase, **WHEN** focus lost, 100 ticks, Start, call, focus lost again and resume, **THEN** `phase_changed(Paused)`, then `phase_changed` naming the phase it left; the countdown is unchanged; A, B and C do not tick during the 100. After a resume to Wave or Intermission, one tick adds 1 to each; after a resume to Build it adds none, since Build's clock is stopped.
13. (Rule 18) **GIVEN** each of Build, Wave, Intermission, Paused, Won and Lost, **WHEN** the handler fires twice, then ticks, events, Start, call and resume, **THEN** one `phase_changed(Fatal)`, the first cause is kept, `cancels` rises by 1, A, B and C stop ticking, and no other transition follows.
14. (Rule 5) **GIVEN** two flows and the script Start, `wave_cleared(1.0)`, 2 ticks, call, leak 2, `wave_cleared(1.0)`, 4 ticks, `waves_completed`, **THEN** both logs equal `phase_changed(Wave), phase_changed(Intermission), wave_called_early(0.5), phase_changed(Wave), lives_changed(1), phase_changed(Intermission), phase_changed(Wave), phase_changed(Won)`.
15. (Formulas) **GIVEN** `wave_cleared(0.0)`, **WHEN** call, **THEN** an empty log and 1 start; **WHEN** one tick, **THEN** `phase_changed(Wave)` and 2 starts.
16. (Rule 15) **GIVEN** Wave, **WHEN** Lost, Won, Fatal or Paused commits, **THEN** at the emit the listener reads that phase and `cancels` 1, with `halted()` true except in Paused.
17. (Rule 15) **GIVEN** Wave with `wave_index()` 2, **WHEN** Lost, **THEN** the result reads Lost, 2, 0 lives and a fake Combat's damage by source. `in_build()` is true only in Build and in Paused from Build; `halted()` only in Won, Lost and Fatal.
18. (Rule 15) **GIVEN** Intermission with `intermission_left` 2 at `dt` 0.25, the recorder connected first, and a second listener that fires the handler on `wave_called_early`, **WHEN** call, **THEN** `wave_called_early(0.5), phase_changed(Fatal)`, with no `phase_changed(Wave)`, and starts risen by 1.
19. (Rule 15) **GIVEN** `stage(1)` in Wave on a battle with no cancel set, **WHEN** a leak of cost 1, **THEN** `lives_changed(0), phase_changed(Lost)` and 0 sink entries.
20. (Rule 7) **GIVEN** Wave with `E` in the tick list, emitting `wave_cleared(1.0)` from inside its tick, **THEN** the log is `phase_changed(Intermission)`, and the systems after `E` tick as usual.

**Deferred criteria.** Done for this system means every numbered criterion passes and each of these has its owner.

| Criterion | Owner | Passes when |
|---|---|---|
| Retry (Rules 2, 2a, 16) | Game State stories | A retried battle's snapshot equals a fresh one; a `weakref` to the old battle, every system, the accessor and the resolver is null; only the catalogue is the same object. A latch set outside Won or Lost causes no rebuild. A move from a finger held across a retry is dropped until it lifts |
| Full determinism (Rule 5) | Combat stories | The same stage, seed and script give an identical result |
| Listener test | Game State stories, once Enemy & Wave and Tower exist | The system count is non-zero, and removing one connection fails naming it; watched failing once, with the output kept |
| Micro-battle | Game State stories, once Combat, Enemy & Wave and Tower exist | A kill raises gold by the bounty, a leak drops lives, and clearing all waves wins |
| Boot (Rules 1, 2, 18) | Game State stories | Each of a failed load, a stage scene that fails to load, a bad accessor call, a wrapper given a hand-built Input record (`drag_slop` 7) so `create` returns null, a null Stage record to `build`, and the handler fired during `build` leaves the app root in Fatal with the first cause kept and no battle ticking after the latch. The null `create` builds no adapter and raises no script error. The partial build is discarded with 0 ticks. The failed load builds the screen with a null catalogue. A bad accessor call in a retried battle still reaches Fatal, so the handler survives a retry |
| Cancel wiring (Rule 15) | Game State stories | With a real wrapper and resolver and an aim Dragging, Lost, Won and Fatal each give one `drag_cancelled`, and retry cancels before the old battle is removed. With `set_input_cancel` removed, the Lost case fails; watched failing once. A finger held across Paused sends no tap, and its moves are dead until it lifts |
| Lifecycle mapping (Rule 17) | ADR-0001, with its device spike | Focus loss and backgrounding each reach `pause()` once, and a resize does not. Which notifications fire per OS cannot be sourced until then |
| Injection of resolver and adapter (Input) | Game State stories | Every owner receives the one resolver, with no global |
| Clock (Rules 4, 5, 17) | Game State stories, with the cap from ADR-0004 | A frame owing more than the cap runs exactly the cap's ticks. `phase_changed(Paused)` zeroes the accumulator, so a resume runs 0 ticks from time owed before the pause. Systems tick in the listed order |
| Bonus and live actions (Rules 9, 10) | Tower stories | A bonus is paid per real call only, regardless of burst state; actions work in all three phases; the burst is refused in Build (Hero) |
| Call-early gates (Rule 9) | Hero stories | Hero's deferred table holds the numbers: on every mixed build, calling when the burst is Ready ends within 2 lives of never calling; a won stage with every wave called runs at least 3.5 minutes; towers-only always-call flips no loss. Mono-role builds that call are reported, and human logs decide (Hero). Re-baselined on the fixed tick |
| Button arming | Battle HUD stories | A press begun before Start/Call or Retry arms does nothing |

**Manual**
- (Rule 17, desktop) In each phase: unfocus, refocus, tap. The game is frozen, and the tap resumes and reaches nothing beneath. Repeat on the first phone build.
- Retained screenshots of the fatal, Won and Lost screens in `production/qa/evidence/`.
- Won's 0.4 s beat, watched once on a first playable: it reads as a beat and not a hang.

**Checked by code review, not tests:** no gameplay branch in the builder (Rule 3), no `_process` in gameplay systems (Rule 4); no lambda or `bind()` on an injected callable (Rule 2a).

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Do calling gates hold on real bots, and do human callers lose more than waiters? A fast-forward is meant to be safe, so overlapping waves are not a planned fallback; they return only if the user wants calling to carry risk | qa-lead + Hero stories | First playable |
| ADR-0001 (pause mechanism, lifecycle notifications, teardown) and ADR-0004 (tick rate, order and clamp). All engine behaviour here is from memory | technical-director | Before the first story |
| Does a doomed stage need an exit? Retry on Paused is deferred | User + first-run test | First playable |
| Should the result's reads fall back to text, so a bad read cannot turn a Won screen into Fatal? Today Fatal wins (Rule 18) | technical-director | ADR-0001 |
| Bots must be re-baselined on the fixed tick; the prototype's 10-vs-3 lives result does not transfer | qa-lead | First playable |
| How do tests take a battle snapshot, enumerate its systems and inject recording ones? The criteria assume all three, and propose a test constructor | technical-director | ADR-0007 |
| Does the technical director accept moving the composition root from the battle scene to a plain builder? | technical-director | ADR-0001 |
