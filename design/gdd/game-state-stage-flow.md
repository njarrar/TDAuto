# Game State & Stage Flow

> **Status**: Designed (pending independent review)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-11-01 — CONCERNS applied (call-early cost restated, always-call bot gate, button arming and test coverage, leaks per lane cut). User kept call-early and focus freeze in MVP.
> **Author**: njarrar + agents
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-02
> **Implements Pillar**: Enabling system for all four pillars; Pillar 3 most directly (a new stage gets time to be read, and a lost stage retries at once)

## Summary

Boots the app, holds the catalogue, runs each battle through Build, Wave and Intermission, owns lives, and decides Won or Lost. Players feel it as pacing: time to read a new path, and a timer they can beat by calling the next wave early for bonus gold. Retry rebuilds the whole battle, and a battle can run with no scene or real time, which is how bots and tests measure the game.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Data & Config Pipeline`

## Overview

Game State & Stage Flow is what makes a stage begin, advance and end. It boots the app, holds the loaded catalogue, starts each battle, connects the other battle systems to each other, owns the player's lives, and decides when a stage is won or lost. Players meet it as pacing: a stage waits while they read the path, then waves come on a timer they can beat by calling the next wave early for bonus gold, which shortens the burst's recovery. Whether that is a real decision depends on tuning: the field is clear between waves, so a bot gate checks it does not become a free habit. A lost stage retries at once with nothing carried over. It exists so that no other system needs to know about any other, and so a whole battle can run with no scene, no renderer and no real time, which is how the bots and tests measure the game. It owns phases and lives, not enemies, gold or towers.

## Detailed Design

### Core Rules

**Roots.**

1. **App root.** The main scene is a minimal root with no gameplay references and no autoload. It triggers the catalogue load, holds the Ready catalogue for the whole session and owns the fatal screen. Because it exists before the load, a catalogue failure has somewhere to go. The only things that survive a retry are this root and the catalogue.
2. **Battle builder.** A plain builder, `build(catalogue, stage_id, seed, fatal_handler)`, constructs one battle and connects its systems in one function of explicit signal connections, so the parser catches a misspelt name. It needs no scene, so bots and tests call it directly. This amends the technical director's note, which named the battle scene script: a scene-owned root cannot run headless. A thin scene wrapper adds the tick loop, the input adapter and the views, and holds no gameplay logic.
3. **No god object.** The stage flow and lives live in a pure object. The builder only wires, and a branch on a gameplay value inside it or the wrapper is a defect. Not owned here: gold, the enemy roster, wave contents and durations, spawn timing, stars, saves, gesture rules, screen layout, or what happens inside any system's tick.

**Time.**

4. **One way in.** Simulation time enters only through `battle.tick(dt)`. Gameplay systems use no `_process`, engine timers, `await`, wall clock or physics areas, only countdowns and distance checks. Humans and bots run the same fixed tick (60 per second proposed, matching the Data & Config interval floor); the wrapper accumulates real time and clamps a long frame. Prototype numbers came from variable time for humans and 1/30 for bots, so they do not transfer and bots must be re-baselined. Authored durations become whole ticks through one conversion, `to_ticks` (Enemy & Wave GDD), since a repeated float countdown drifts: 5.0 s took 301 ticks.
5. **Fixed order, commands between ticks.** Systems tick in a fixed order, each owning GDD agreeing its place. Player and bot commands apply only between ticks, never during one. Randomness uses the injected seed: the same stage, seed and command script give an identical result.

**Stage phases.**

6. **Build.** A stage opens in Build with its clock stopped, so the player can read the new path. Wave 1 starts only when the player taps Start Wave. There is no timer here.
7. **Wave.** A wave runs until Enemy & Wave reports `wave_cleared`, meaning all its groups have spawned and every enemy, including any it spawned, has died or leaked. The last wave reports `waves_complete` instead, so Flow needs no wave count.
8. **Intermission.** After every wave but the last, a countdown runs. Enemy & Wave owns its duration and sends it as the payload of `wave_cleared`. The simulation keeps ticking, so the burst keeps recovering. When it reaches 0 the next wave starts.
9. **Call early.** During Intermission the same button starts the next wave at once. Flow emits `wave_called_early(seconds_left)`, and the Tower GDD turns that into bonus gold. Calling costs recovery and preparation time only: less time passes for the burst to recover and for re-pinning and building. The field is clear between waves, so once the burst is ready the cost is small, and a player who ignores the hero pays none of the burst part. The bonus must never depend on burst state, which would turn the hero into an economy timer. A wave cannot be called while another is running at MVP; allowing overlap is the fallback if the always-call bot below shows dominance. Bots do not call early unless a mode says so, and a **towers-only, always-call** mode joins the Pillar 2 bot gates.
10. **Actions are never phase-locked.** Building, upgrading and re-pinning stay live in Build, Wave and Intermission, and a change of phase never cancels a gesture. In Build, towers and pins apply at once, while movement and timers begin on the first tick. The burst is the exception: Hero refuses it in Build, since a stopped clock would never let it recover.

**Lives and outcome.**

11. **Lives.** Flow owns lives, starting at the stage's `starting_lives`. On `enemy_leaked(lives_cost)` it applies the lives formula and, if lives changed, emits `lives_changed(current)`.
12. **Lost.** The first leak that takes lives to 0 ends the stage on that tick, as Lost.
13. **Won.** Enemy & Wave's `waves_complete` means every group of every wave has spawned and every enemy has died or leaked. It is the whole win test, because Flow keeps no enemy count that could disagree with the roster. Enemy & Wave must emit leak events synchronously and before `waves_complete`.
14. **A tie is a loss.** Under Combat's tick order leaks resolve before fire, so a fatal leak ends the tick before any kill. If `waves_complete` still arrives after that, the stage stays Lost and the event is ignored.
15. **The outcome latches.** Won, Lost, Paused, Fatal and retry commit their state, stop the clock, cancel input, then emit (`phase` names each of Won, Lost, Paused and Fatal, which Tower's chip listens for); the phase changes between Build, Wave and Intermission do none of this. An outcome or Fatal committed mid-tick makes the remaining systems skip that tick, so nothing changes the result afterwards. The battle exposes `in_build()`, which Hero uses to refuse the burst, and one `halted()`, true on Won, Lost and Fatal, for systems whose own loops must stop. Won and Lost are terminal and later ticks do nothing. The result stays readable after the outcome: outcome, last wave started (Enemy & Wave's `wave_index()`, injected by the builder, so Flow still keeps no wave count), lives left and Combat's damage by source, shown as plain text at MVP.
15a. **Events out of phase.** A `wave_cleared` or `waves_complete` in the wrong phase, or an `enemy_leaked` in Build, Paused or after an outcome, is a contract breach by Enemy & Wave: development builds log an error and the event is ignored. An `enemy_leaked` in Intermission also logs an error but still applies, because losing a life must never be silently dropped.

**Retry.**

16. **Rebuild, never reset.** Retry destroys the whole battle and builds a new one; no system has a reset function. The prototype's hand-listed reset of 22 fields is exactly how state leaks between attempts. The Retry button only sets a latch on the app root, whose frame acts on it, Fatal first. The order is: stop the clock, cancel input, remove the old battle at once, build the new one. It happens between ticks, never inside a signal. The input resolver and adapter are rebuilt too, because their registrations belong to dying owners. A retried battle opens in Build, skipping the path's draw-in.

**Pause.**

17. **Focus loss freezes.** There is no pause button at MVP. Losing focus or backgrounding the app enters Paused on desktop and phone alike, so the path is proven before the first phone build. The clock stops, so `battle.tick` returns at once, and input cancels. Paused never ends by itself: a tap resumes and reaches nothing beneath, with no countdown. The tick accumulator is zeroed, so no time jump follows, and a finger down across the pause stays dead until lifted. Pausing a terminal state does nothing. An app killed by the OS loses the stage, since nothing is saved at MVP. There is no quit button.

**Fatal.**

18. **Fatal latches and halts.** The failure handler is idempotent and keeps the first cause. It sets a latch on the battle and on the app root, stops ticks and skips the remaining systems in the current tick. If it fires during `build`, the root discards the partial battle without ticking it. GDScript has no exceptions, so the calling function still finishes on a garbage value: therefore, once Fatal is set, nothing persists and no other transition is legal. A failed catalogue load, a bad accessor call and a broken stage scene all take this one path to the generic screen, which uses no catalogue data.

**Wiring is tested, not trusted.** An unconnected signal is a silent bug, so one test fails if any signal of any battle system has no listener, unless it is on a named allowlist for views, and a scripted micro-battle proves the targets are right: a kill raises gold by the bounty, a leak drops lives, and clearing all waves wins.

**Handed to owning GDDs.**
- **Enemy & Wave:** `wave_cleared`, `waves_complete`, `enemy_leaked(lives_cost)`, the leak-before-complete order, keeping spawned children on the roster atomically so a wave cannot clear early, the `intermission_duration` field on the Wave record, a cap on `start_delay` (a wave cannot be called early, so a long one is an empty field), and its place in the tick order. Leaks per lane are cut until a map has more than one lane.
- **Hero:** refuses the burst in Build, and balances burst cooldown against `intermission_duration` with Enemy & Wave.
- **Tower:** the early-call bonus value, priced knowing that a ready burst makes calling nearly free, and never dependent on burst state, and one direct build command shared by the arc and the bots, since the arc lives in the HUD and is absent headless. Input's Rule 11 has bots call Hero's and Tower's commands directly.
- **Combat:** per-source damage counters readable after the outcome.
- **Battle HUD:** the Start/Call button, the outcome screen and the resume tap. Input's adapter gains a lifecycle signal for Flow.

**Deliberately not built for MVP.** Menus and stage select, saves, stars, grades, a report screen, game speed-up, calling a wave during a wave, a manual pause, a quit button, in-place reset, an event-bus autoload, a dependency-injection container, a state-machine framework, a scene stack and replays.

→ Becomes an ADR (App Lifecycle & Composition): tick rate, order and clamp; builder ownership and lifetime; retry teardown including views; the pause mechanism; which lifecycle notifications fire on each platform; guaranteeing the fatal scene loads; the main scene. **None of this is in the pinned engine reference, so every engine behaviour is unverified until that ADR checks live 4.7 docs and a phone run.**

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
| Build | Stopped | Start Wave → Wave 1. Focus loss → Paused. Failure handler → halted, from any state |
| Wave | Running | `wave_cleared` → Intermission. `waves_complete` → Won. Lives 0 → Lost. Focus loss → Paused |
| Intermission | Running | Countdown 0 or call early → next Wave. Lives 0 → Lost (a contract breach, Rule 15a). Focus loss → Paused |
| Paused | Stopped | Resume tap → the phase it left |
| Won | Stopped, latched | Retry → new battle |
| Lost | Stopped, latched | Retry → new battle |

### Interactions with Other Systems

| System | Direction | Interface | Owner |
|---|---|---|---|
| Data & Config Pipeline | reads | App root triggers load and holds the catalogue; reads the Stage record; receives the failure handler's calls | Data (load, lookup); this system (root, screen) |
| Input & Gesture Resolver | builds | Wrapper builds resolver and adapter per battle; Won, Lost, Paused, Fatal and retry call `cancel()`; adapter forwards a lifecycle signal | Input (API); this system (composition) |
| Enemy & Wave | wires, commands | Listens to `wave_cleared`, `waves_complete`, `enemy_leaked`; calls start next wave; reads `wave_index()` for the result | Enemy & Wave (signals) |
| Tower System | wires | Forwards `wave_called_early(seconds_left)`; connects kills to gold | Tower (bonus value) |
| Hero System | wires | Builds and ticks it; injects `halted()` and `in_build()`; reads `left_handed` from Data's Input record and the one Hero record's ID and `burst_id`, passing the IDs and the hand to HeroSim, the hand to the wrapper's HeroInput and HUD, and the Burst's ID to the HUD for the wedge (Hero Rules 2, 8; Battle HUD Rule 12) | Hero |
| Combat & Damage | wires, reads | Reads per-source counters for the result | Combat |
| Battle HUD | listens | `lives_changed`, `phase`; reads lives, `in_build()`, `intermission_left`, result; sends Start/Call, Retry, resume | HUD (drawing, button placement) |
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
**Example:** 720 ticks left, player calls: `wave_called_early(12.0)`, and the next wave starts in the next tick.

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
- **If the last wave clears**: `waves_complete` applies; there is no Intermission and the button is gone.
- **If focus is lost in Won, Lost or Fatal**: no state change.
- **If focus is lost and the OS kills the app**: the stage is lost and the next launch boots cold.
- **If a finger is held across a retry**: the new adapter never saw its press, so its moves are dropped and it must lift first.
- **If Retry arrives outside Won or Lost**: ignored. Paused is not stuck, because a tap exits it.
- **If Retry is tapped twice**: one rebuild; the second tap belongs to a destroyed button or is a new press in Build, where it reaches whatever is beneath.
- **If a press began before the outcome screen armed**: it does not count as a Retry tap (Game Feel).
- **If a bad accessor call happens mid-tick**: Fatal latches, the remaining systems skip that tick, and the calling function finishes on a value nothing persists.
- **If the failure handler fires twice**: the first cause is kept.
- **If a stage scene is broken**: Fatal at stage start; the catalogue stays Ready, though there is no way out at MVP but relaunching.
- **If a press began before Paused**: it never resumes, and stays dead until lifted.
- **If the handler fires during `build`**: the partial battle is discarded unticked, and Fatal shows.
- **If a long frame hits (app hitch)**: the wrapper clamps the ticks owed, so the game slows rather than jumping. The clamp value belongs to the ADR.

## Dependencies

**Upstream (hard):** Data & Config Pipeline, for load, the failure path and the Stage record.

**Downstream (hard; none but Input has a GDD, so each interface is provisional until that GDD confirms it):**

| System | Interface |
|---|---|
| Input & Gesture Resolver | Built per battle; cancelled on outcome, pause, fatal and retry; forwards lifecycle |
| Enemy & Wave | Emits the wave signals; owns durations |
| Tower System | Early-call bonus; kills to gold; direct build command |
| Hero System | Built and ticked here; receives `halted()`, `in_build()`, the hand and the Hero's and Burst's IDs |
| Combat & Damage | Per-source counters readable after the outcome |
| Battle HUD & Build UI | Draws phases, lives, countdown, result; sends commands |
| Stage Progression & Stars (VS) | Reads the result (soft at MVP) |
| Save/Load, Menu & Screen Flow (VS) | Join the app machine (soft at MVP) |

Per the bidirectional rule, each of these GDDs must list this one when authored.

## Visual/Audio Requirements

This system draws nothing but the fatal screen, and every other visual is triggered by its signals, per `design/art/art-bible.md` §2:

| Event | Visual (owner) | Art bible |
|---|---|---|
| Stage opens | Path draws itself in; skipped on retry (HUD or stage scene) | §2 Build |
| Lost | Hero dims to an outline; retry is the only filled shape (HUD, Hero) | §2 Defeat |
| Won | Tower bodies brighten in sequence, deferred past MVP; a compact panel leaves the board in view (HUD) | §2 Victory |
| Fatal | Generic text on the field colour, no catalogue data (this system) | — |

Audio: none at MVP.

## Game Feel

All durations are proposed, untested and presentation only, so the wrapper runs them outside the simulation.

- **Lost is immediate.** The simulation freezes on the tick lives reach 0, in-flight drags cancel without firing, and the screen appears about 0.4 s later.
- **Won breathes.** Input is dead for a beat of about 1 s, then the screen appears.
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
| Composition root | `design/gdd/systems-index.md` | Core Layer TD note | Amended here |
| Between-waves loop, MVP win/lose, retry | `design/gdd/game-concept.md` | Core Loop, Flow State, MVP | Rule dependency |
| Mood per state, panel placement | `design/art/art-bible.md` | §2, §7 | Ownership handoff |
| Reset and timing evidence | `prototypes/hero-pin-concept/main.gd` | `_start`, `_step`, `_run_bots` | Evidence |

## Acceptance Criteria

A recording fake logs every Flow signal, and each THEN is the entire log; anything unlisted fails. A factory builds `stage()`: 3 lives, 3 waves, intermission 1.0 s, `dt` 0.25 (binary-exact). A fake Enemy & Wave `E` counts wave starts and emits on command. No scene, no random seeds, no time assertions.

**CI: Logic**
1. (Rule 6) **GIVEN** a new flow, **WHEN** 100 ticks, **THEN** an empty log and 0 starts; **WHEN** Start twice, **THEN** `phase(Wave)` and 1 start.
2. (Rules 7, 8) **GIVEN** wave 1, **WHEN** `wave_cleared` and 3 ticks, **THEN** `phase(Intermission)` and 1 start; a 4th tick appends `phase(Wave)`, and 2 starts.
3. (Rule 9) **GIVEN** Intermission after 2 ticks, **WHEN** call twice, **THEN** `wave_called_early(0.5), phase(Wave)`, and 2 starts.
4. (Rule 9) **GIVEN** Build, any Wave, or just after expiry, **WHEN** call, **THEN** nothing appended and starts unchanged.
5. (Rule 13) **GIVEN** the last wave, **WHEN** `waves_complete`, **THEN** `phase(Won)`.
6. (Rules 11, 12) **GIVEN** 3 lives, **WHEN** cost 2, **THEN** `lives_changed(1)`; a following cost 3 or 5 gives `lives_changed(0), phase(Lost)`; cost 0 gives an empty log. A further same-tick leak appends nothing.
7. (Rule 14) **GIVEN** 1 life, **WHEN** a leak then `waves_complete` on one tick, **THEN** `lives_changed(0), phase(Lost)`.
8. (Rule 15) **GIVEN** Won or Lost, **WHEN** ticks, every event, every command and focus loss, **THEN** nothing appended and the result unchanged. Listeners see the state committed, the clock stopped and `cancel()` already called.
9. (Rule 15) **GIVEN** recording systems A, B, C, **WHEN** B's tick triggers Lost, **THEN** C does not tick that tick.
10. (Rules 7, 10, 15) **GIVEN** each change among Build, Wave and Intermission, **THEN** `cancel()` is not called.
11. (Rule 15a) **GIVEN** Build, **WHEN** `enemy_leaked(2)`, **THEN** an empty log and lives unchanged. **GIVEN** Intermission, **WHEN** `enemy_leaked(2)`, **THEN** `lives_changed(1)`.
12. (Rule 17) **GIVEN** each live phase, **WHEN** focus lost, 100 ticks, commands, focus lost again, resume, **THEN** that phase returns and the countdown is unchanged.
13. (Rule 18) **GIVEN** recording systems A, B, C, **WHEN** B fires the handler twice, then ticks and events, **THEN** the first cause is kept, C never ticks, and no transition follows.
14. (Rule 5) **GIVEN** two flows and one script, **THEN** identical logs.
15. (Formulas) **GIVEN** a duration of 0, **WHEN** Intermission starts and one tick runs, **THEN** the next wave starts; a call at that moment emits no signal.

**Deferred criteria.** Done for this system means every criterion runnable today passes and each of these has its owner.

| Criterion | Owner | Passes when |
|---|---|---|
| Retry (Rules 2, 16) | Enemy & Wave stories | A retried battle's snapshot equals a fresh one; a `weakref` to the old battle is null; only the catalogue is the same object |
| Full determinism (Rule 5) | Combat stories | The same stage, seed and script give an identical result |
| Listener test | Enemy & Wave, Tower stories | The system count is non-zero, and removing one connection fails naming it; watched failing once, with the output kept |
| Micro-battle | Combat stories | A kill raises gold by the bounty, a leak drops lives, and clearing all waves wins |
| Boot (Rules 1, 18) | Game State stories | A failed load and a broken scene both reach the fatal screen |
| Clamp and tick order (Rules 4, 5) | App Lifecycle ADR | Ticks are capped, and the order matches the GDDs |
| Bonus and live actions (Rules 9, 10) | Tower stories | A bonus is paid per real call only, regardless of burst state; actions work in all three phases; the burst is refused in Build (Hero) |
| Always-call bot gate (Rule 9) | Hero stories | A towers-only, always-call bot must not beat a driven hero; re-baselined on the fixed tick |
| Button arming | Battle HUD stories | A press begun before Start/Call or Retry arms does nothing |

**Manual**
- (Rule 17, desktop) In each phase: unfocus, refocus, tap. The game is frozen, and the tap resumes and reaches nothing beneath. Repeat on the first phone build.
- Retained screenshots of the fatal, Won and Lost screens in `production/qa/evidence/`.

**Checked by code review, not tests:** no gameplay branch in the builder (Rule 3), no `_process` in gameplay systems (Rule 4).

## Open Questions

| Question | Owner | Resolve by |
|---|---|---|
| Does the always-call bot dominate? If so, the fallback is allowing overlapping waves | qa-lead + Tower GDD | First playable |
| App Lifecycle & Composition ADR: tick rate and clamp, pause mechanism, lifecycle notifications, teardown. All engine behaviour here is from memory | technical-director | Before the first story |
| Bots must be re-baselined on the fixed tick; the prototype's 10-vs-3 lives result does not transfer | qa-lead | First playable |
| How do tests take a battle snapshot, enumerate its systems and inject recording ones? The criteria assume all three | technical-director | App Lifecycle ADR |
| Does the technical director accept moving the composition root from the battle scene to a plain builder? | technical-director | Input and Game State ADR |
