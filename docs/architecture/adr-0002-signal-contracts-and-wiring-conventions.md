# ADR-0002: Signal Contracts and Wiring Conventions

## Status
Accepted (2026-11-02, by njarrar; the Migration Plan edits landed in the same change)

## Date
2026-11-02

## Last Verified
2026-11-02

## Decision Makers
njarrar (project owner); technical-director and lead-programmer (architecture gates, 2026-11-02, finding GF10). Engine specialist and TD-ADR reviews are recorded under Related.

## Summary
Eight systems talk through signals and reads, and the GDDs and the architecture spell several of them differently (warning M4), so stories would build against names that disagree. This ADR fixes one canonical table of every signal, read and command, and the rules for declaring, wiring and testing them: typed signals, explicit connections in two places only, no event bus, and a wiring test whose view allowlist each system declares in code.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scripting, signals) |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM: signals and `Callable` connections are long-stable, but the pinned reference covers only lambda capture and rest parameters (`current-best-practices.md`), not signal dispatch |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md` (string `connect` is deprecated; use `signal.connect(callable)`), `current-best-practices.md` (lambdas capture locals by value; a rest-parameter lambda connects to any signal) |
| **Post-Cutoff APIs Used** | Typed dictionaries (`Dictionary[StringName, int]`), added in 4.4 (memory, unverified; 4.4 is inside the knowledge gap). 4.7's typed-return override rule applies to any record or test double that overrides a typed method: it needs an explicit `return` |
| **Verification Required** | **NOT SOURCEABLE** from `docs/engine-reference/godot/` (no signal coverage): (S1) listeners of one signal run in connection order; this ADR is written so that nothing depends on it; (S2) `(get_script() as Script).get_script_signal_list()` lists script-declared signals, including those of inherited scripts but not native-class signals, with `name` as a `String`; and `get_signal_connection_list(name)` (an `Object` method) reports `Callable` connections on a `RefCounted`; the wiring test relies on both; (S3) typed signal parameters are not checked at `emit` time, so a wrong argument type is not caught by the engine; this ADR adds a test instead. Each is checked by the first wiring-test story on 4.7.2 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): reads and commands use its ID and record names (`tower_id`, `TowerDef`, `StatAccessor`) |
| **Enables** | ADR-0003 (frame order uses `Battle.enqueue` and the emit rules), ADR-0004 (the harness listens through this table), ADR-0005 (owns `EnemyInstance` named here), ADR-0007 (the resolver's signals), ADR-0008 (the builder and wrapper do the wiring defined here) |
| **Blocks** | Every MVP epic: no story may name a signal, read or command until this table is Accepted (GF10) |
| **Ordering Note** | `EnemyInstance` is the name ADR-0005 confirms. If ADR-0005 renames it, it updates this table in the same change |

## Context

### Problem Statement
The cross-review (warning M4) and the architecture gate (GF10) found the same interface spelled two ways in several places: `wave_called_early` carries seconds in the GDDs and ticks in the architecture; `build` takes `tower_id` in the Tower GDD and `role_tag` in the architecture; the resolver's signals carry two winners and the press point in the Input GDD but one target in the architecture; `chip_state()` is on TowerSim in one place and TowerInput in another, with no fields; `lifecycle_changed` has two owners. Flow's rule "wiring is tested, not trusted" needs a test whose covered set is derived, not typed out by hand.

### Constraints
- No autoloads and no event bus (architecture layer rules; registry `catalogue_global_access`).
- The simulation is `RefCounted` and runs headless; views exist only inside the BattleWrapper (Flow Rule 2).
- Gameplay uses no `await`, no engine timers and no `_process` (Flow Rule 4).
- Commands go through one queue applied at the start of `battle.tick` (architecture GF7, ADR-0003) (refined by ADR-0003).
- `halted()` is checked by each emitter (architecture GF8).
- Project naming: signals are past tense (`project.yaml`).

### Requirements
- TR-flow-010: every signal of every battle system has a listener unless it is on the named view allowlist.
- TR-combat-007: `attack_fired` and `damage_applied` carry copied positions and drive a view; no gameplay depends on them.
- TR-hud-006: the HUD reads values each frame, compares whole ticks, and listens only to allowlisted signals.
- GF10: one table of canonical signatures, written before any story.

## Decision

### 1. Declaration rules
1. Every signal is declared with typed parameters: `signal enemy_killed(bounty: int)`.
2. A signal argument is a value (`int`, `float`, `bool`, `StringName`, `Vector2`, `Rect2`) or a read-only record. Positions are copies, never a reference into the simulation (TR-combat-007). The one record argument is `DamageEvent`; a listener must not keep it, or its `target`, after the call returns, because the target may be reaped.
3. Signal names follow the GDDs (section 4). New signals are past tense. The existing names `phase`, `pressed`, `tap`, `ground_tap`, `idle` and `waves_complete` stay as they are: eight GDDs and their criteria cite them, and a rename would change no behaviour. They are the only exceptions.
4. A sim emitter inside a tick checks `halted()` and emits nothing once it is true (GF8). Two named exceptions: StageFlow emits the outcome `phase(Won)`, `phase(Lost)` or `phase(Fatal)` once, after the latch (Flow Rule 18); and the resolver emits `drag_cancelled` and `idle()` from the end-of-frame `cancel()` that follows an outcome. Emitting is synchronous; no gameplay signal uses `CONNECT_DEFERRED` or `CONNECT_ONE_SHOT`.
5. Each battle system declares `const VIEW_SIGNALS: Array[StringName]`: the signals the GDDs mark as read by a view. An empty list is written out as `[]`, never left out.
6. **Signal owners.** StageFlow declares `phase`, `lives_changed` and `wave_called_early`, and owns `start_next_wave()`. `Battle` declares no signals; it only holds the systems and the queue. This keeps every battle signal inside `battle.systems()`, so the wiring test sees it.
7. **No reference cycles.** No system holds `Battle`. `halted()` reaches systems through a small shared `HaltLatch` (`RefCounted`) that the builder creates (the `StatAccessor` needs it before `Battle` exists, ADR-0008) and hands to `Battle` and each system; systems hold the latch, `Battle` holds the systems, and nothing points back. On Retry the wrapper calls `Battle.dispose()`, which disconnects and clears its system list as a backstop.

### 2. Wiring rules
1. **Two places connect signals, and only these two.** `BattleBuilder.build` connects sim to sim (headless). `BattleWrapper` connects sim to view, and the wrapper-only signals of TowerInput and HeroInput. No system connects itself to another system, and no view connects to anything outside the wrapper.
2. Connections are written as `emitter.signal_name.connect(listener.method)` with a bound method. The builder and the wrapper hold every emitter and listener in a **statically typed** variable (`var wave: WaveSim = ...`), because the parser catches a misspelt signal or method name only on a typed reference. String `connect` is banned (`deprecated-apis.md`).
3. A lambda may be connected only if it captures nothing it then writes; lambdas capture locals by value (`current-best-practices.md`), so a lambda that sets an outer local silently does nothing. Use a bound method instead.
4. **No order between listeners.** No result may depend on which of two listeners of one signal runs first (S1 is unsourced). This applies to view listeners too: `phase`, `pressed` and `lifecycle_changed` each have several, and each listener must be correct whichever runs first. Where order matters, the signal has one listener, and that listener calls the next step itself. Every sim signal has at most one sim listener, and the wiring test checks it.
5. Views never write. A view reads through `Battle.flow()`, `combat()`, `wave()`, `tower()`, `hero()` and queues commands through `Battle.enqueue` (architecture 4.3, GF7). Systems never use those reads to reach each other.
6. Gameplay never `await`s a signal.
7. On Retry the wrapper drops the old battle and views and wires the new ones; it never re-connects into a freed battle (architecture 3.5).

### 3. The wiring test (TR-flow-010)
The covered set is derived, not listed (refined by ADR-0004):

- **Headless test.** Build a battle with `BattleBuilder.build` and a fixture catalogue. For each object in `battle.systems()`, take every signal from `(get_script() as Script).get_script_signal_list()` (S2), converting each `name` with `StringName(...)`. Each must have at least one connection (`get_signal_connection_list(name).size() > 0`) unless its name is in that system's `VIEW_SIGNALS`, and **at most one** (only sim listeners exist headless; rule 2.4). A new signal with no listener fails the test without anyone editing it.
- **Allowlist check.** Every name in a `VIEW_SIGNALS` is a real script signal of that system (catches a typo in the list).
- **Wrapper test** (with the wrapper and views built, in `tests/integration/`): the same derivation runs over every object the wrapper builds: each battle system, the GestureResolver, TowerInput, HeroInput and the BattleWrapper itself. Every script signal of the resolver, TowerInput, HeroInput and the wrapper (including `lifecycle_changed`) must have at least one listener, with no allowlist; every `VIEW_SIGNALS` signal of a battle system must also have one. Nothing is typed out by hand.
- **Argument types (S3).** One test per signal emits it from a fixture and asserts the listener receives values of the declared types.

### 4. Canonical table

Sources are the GDDs; where the architecture gate decided a change, the change wins and is marked **(gate)**. "View" means on `VIEW_SIGNALS`.

**Signals**

| Signal | Emitter | Sim listener (builder) | View listener (wrapper) |
|---|---|---|---|
| `enemy_killed(bounty: int)` | WaveSim (reap) | TowerSim (gold) | none |
| `enemy_leaked(lives_cost: int)` | WaveSim (leak) | StageFlow (lives) | none |
| `wave_cleared(intermission_duration: float)` | WaveSim | StageFlow | none |
| `waves_complete()` | WaveSim | StageFlow | none |
| `wave_called_early(ticks_left: int)` **(gate)** | StageFlow | TowerSim (bonus gold) | none; the HUD derives seconds for display |
| `phase(state: StringName)`: `Build`, `Wave`, `Intermission`, `Paused`, `Won`, `Lost`, `Fatal` | StageFlow | none | Battle HUD, TowerInput (chip) (view) |
| `lives_changed(current: int)` | StageFlow | none | Battle HUD (view) |
| `gold_changed(current: int)` | TowerSim | none | Battle HUD (view) |
| `tower_built(slot_index: int, tower_id: StringName)` | TowerSim | none | Battle HUD (view) |
| `tower_upgraded(slot_index: int, level: int)` | TowerSim | none | Battle HUD (view) |
| `hero_pinned(position: Vector2)` | HeroSim | none | Battle HUD (view) |
| `burst_started(aim_point: Vector2, telegraph_ticks: int)` | HeroSim | none | Battle HUD (view) |
| `attack_fired(source_kind: int, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)` | Combat | none | CombatView (view); not the HUD |
| `damage_applied(event: DamageEvent, applied: float, position: Vector2)` | Combat | none | CombatView, Battle HUD (view) |
| `slot_tapped(slot_index: int)`, `tower_inspected(slot_index: int)`, `upgrade_refused(slot_index: int)` | TowerInput (wrapper only) | none | Battle HUD |
| `lifecycle_changed(state: StringName)`: `focus_lost`, `focus_gained`, `quit_requested`, `resized`, `back` **(gate, GF6)** | BattleWrapper | none | StageFlow (through the wrapper), Battle HUD; forwarded to AppRoot through `AppServices.on_lifecycle` (a callable, not a signal connection); `resized` does not pause (ADR-0008) |
| `pressed(best_tap: int, best_drag: int, pos: Vector2)` | GestureResolver | none | HeroInput, TowerInput, Battle HUD |
| `tap(target_id: int, pos: Vector2)` | GestureResolver | none | TowerInput, Battle HUD |
| `ground_tap(pos: Vector2)` | GestureResolver | none | Battle HUD |
| `drag_started(target_id: int, press_pos: Vector2, pos: Vector2)`, `drag_moved(target_id: int, press_pos: Vector2, pos: Vector2)`, `drag_ended(target_id: int, press_pos: Vector2, pos: Vector2)` | GestureResolver | none | HeroInput; Battle HUD (`drag_started` only) |
| `drag_cancelled(target_id: int)` | GestureResolver | none | HeroInput |
| `idle()` | GestureResolver | none | HeroInput, Battle HUD |

`best_tap` and `best_drag` are target IDs, or `-1` for none. The resolver signals live in the wrapper (the resolver is an input object, not a battle system), so the headless test does not cover them; the wrapper test does.

**Reads** (synchronous, any time; compared in whole ticks by the HUD, TR-hud-006)

| Owner | Reads |
|---|---|
| `Catalogue` (ADR-0001) | `tower`, `enemy`, `wave`, `stage`, `hero`, `burst`, `input`, `options`, `is_tower(def_id) -> bool`, `level_count(def_id) -> int`; stats through `StatAccessor` |
| `Battle` | `halted() -> bool`, `in_build() -> bool`, `flow()`, `combat()`, `wave()`, `tower()`, `hero()`, `systems()` |
| `StageFlow` | `state() -> StringName`, `lives() -> int`, `intermission_left() -> int` (ticks), `result() -> BattleResult`, `to_ticks(seconds: float) -> int` |
| `WaveSim` | `roster() -> Array[EnemyInstance]`, `targets() -> Array[EnemyInstance]` (each a read-only array, valid for the reader's own tick slot; refined by ADR-0005: a new typed copy per call), `wave_index() -> int`, `got_through_by_type() -> Dictionary[StringName, int]` (a read-only copy) |
| `TowerSim` | `gold() -> int`, `slot_state(slot_index: int) -> SlotState` (`tower_id`, empty when unbuilt; `level`; `cooldown_left` ticks) |
| `TowerInput` (wrapper) | `chip_state() -> ChipState` (`slot_index`, `-1` when closed; `elapsed_ms: float`, real time, as battle-hud.md writes it; `level: int`) |
| `HeroSim` | `position() -> Vector2`, `pin_state() -> int`, `pin_target() -> Vector2`, `burst_state() -> int`, `cooldown_left() -> int` (ticks), `counters() -> HeroCounters` |
| `HeroInput` (wrapper) | `aim_state() -> int`, `aim_point() -> Vector2`, `hero_target_id() -> int`, `cooldown_digit() -> int` |
| `Combat` | `hp_left`, `is_dead`, `speed_factor` (architecture 4.4), `counters() -> CombatCounters` (per source) |

`SlotState`, `ChipState`, `HeroCounters`, `CombatCounters` and `BattleResult` are small read-only `RefCounted` records, not Dictionaries (registry `mutable_catalogue_records` applies the same reason). Their fields are the GDD fields; the owning story adds a field by updating this table. ADR-0005 section 4 lists the fields (refined by ADR-0005). Every battle system also has `snapshot() -> Dictionary`, a read for tests only, in the format of ADR-0004 section 5 (refined by ADR-0004).

**Returned collections.** A read that returns an `Array` or `Dictionary` returns one the caller cannot write into the simulation: either a copy, or the owner's array after `make_read_only()` (memory, unverified on 4.7.2; if it is missing or costly, the owner returns `.duplicate()`). The first WaveSim story picks one and records it here. Recorded by ADR-0005: WaveSim returns a new typed copy per call (`.duplicate()`); `make_read_only()` is not used (refined by ADR-0005).

**Commands** (queued through `Battle.enqueue` and applied at the start of the next tick, GF7 (refined by ADR-0003); bots call the same commands through the same queue). The result codes are each command's own contract and are what the command returns when the queue applies it. How a refusal reaches the HUD, given that `enqueue` does not return it, is ADR-0003's to decide (Open Question A11).

| Command | Owner | Result codes |
|---|---|---|
| `build(slot_index: int, tower_id: StringName) -> int` | TowerSim | `OK`, `HALTED`, `BAD_SLOT`, `BAD_TOWER`, `SLOT_OCCUPIED`, `NO_GOLD` |
| `upgrade(slot_index: int) -> int` | TowerSim | `OK`, `HALTED`, `BAD_SLOT`, `NO_TOWER`, `MAX_LEVEL`, `NO_GOLD` |
| `pin(position: Vector2) -> int` | HeroSim | `OK`, `HALTED`, `BAD_POSITION`, `OUT_OF_BOUNDS`, `BUTTON_ZONE` |
| `burst(aim_point: Vector2) -> int` | HeroSim | `OK`, `HALTED`, `BUILD_PHASE`, `NOT_PINNED`, `NOT_READY`, `BAD_POSITION`, `OFF_FIELD`, `OUT_OF_REACH` |
| `start_next_wave() -> void` | StageFlow (forwards to WaveSim); not on `Battle` | none |
| `resume() -> int` (queued as `ResumeCommand`, ADR-0006, ADR-0008) | StageFlow | `OK`, `HALTED`, `NOT_PAUSED` |

**AppRoot calls** (not queued; the app root is not a battle system): `request_retry() -> void` sets the Retry latch (Flow Rule 1, HUD Rule 3); `set_call_prompt_done() -> void` sets `call_prompt_done` (Flow Rule 1, HUD Rule 13). The GDDs name the state but not the functions; these names are fixed here.

**Input registry calls** are as architecture 4.2 (`register`, `unregister`, `set_centre`, `set_enabled`, `press`, `move`, `release`, `cancel_pointer`, `cancel`).

### Architecture Diagram

```
BattleBuilder.build (headless)               BattleWrapper (scene)
  WaveSim --enemy_killed--> TowerSim           GestureResolver --pressed/tap/drag_*--> HeroInput, TowerInput, HUD
  WaveSim --enemy_leaked/wave_cleared/         TowerInput --slot_tapped/...--> HUD
           waves_complete--> StageFlow         StageFlow/TowerSim/HeroSim/Combat --VIEW_SIGNALS--> HUD, CombatView
  StageFlow --wave_called_early--> TowerSim    BattleWrapper --lifecycle_changed--> StageFlow, HUD, AppRoot
                                               views --enqueue(command)--> Battle --tick--> owners
```

### Key Interfaces
The canonical table above is the interface. Every system's `VIEW_SIGNALS` constant is part of it.

### Implementation Guidelines
- Every signal must be declared with typed parameters and listed in the table above before a story uses it.
- Code must connect signals only in `BattleBuilder.build` or `BattleWrapper`.
- Code must never use string `connect`, `CONNECT_DEFERRED` or `CONNECT_ONE_SHOT` for a gameplay signal.
- Code must never depend on the order in which two listeners of one signal run.
- A sim emitter must never emit after `halted()` is true, except the two named in declaration rule 4.
- The builder and the wrapper must hold emitters and listeners in statically typed variables.
- No system may hold a reference to `Battle`; systems get `halted()` through the shared `HaltLatch`.
- A listener must never keep a `DamageEvent` or any `EnemyInstance` after it returns.
- A view must never call a command directly; it uses `Battle.enqueue`.
- Gameplay code must never `await` a signal.
- Every battle system must declare `VIEW_SIGNALS`, even when empty.
- Reads return values or read-only records, never a Dictionary a caller could write into the simulation.

## Alternatives Considered

### Alternative 1: An event-bus autoload
- **Description**: One global `Events` node holding every signal; systems emit and connect through it.
- **Pros**: No wiring code; easy to add a listener.
- **Cons**: A hidden global, breaks headless fixtures and tests that build two battles side by side; the wiring test cannot tell which system owns a signal; banned by the architecture's no-autoload rule.
- **Rejection Reason**: Contradicts the layer rules and registry `catalogue_global_access`.

### Alternative 2: Systems connect themselves in `_init`
- **Description**: Each system is handed its peers and connects its own listeners.
- **Pros**: Wiring sits next to the code that uses it.
- **Cons**: Every system then holds references to peers, the dependency graph is spread over eight files, and the builder can no longer show the whole wiring in one place.
- **Rejection Reason**: The architecture chose a plain builder as the one place that knows the graph (A2).

### Alternative 3: A hand-written allowlist in the test
- **Description**: The wiring test holds a list of signals that may go unheard.
- **Pros**: One file to read.
- **Cons**: The list pins what was known when written and stays silent about every signal added since (`.claude/rules/skill-authoring.md`, obligation 5).
- **Rejection Reason**: Each system's `VIEW_SIGNALS` lives next to the signal it names and is itself checked against the script's signal list.

### Alternative 4: Rename every signal to past tense
- **Description**: `phase` to `phase_changed`, `tap` to `tapped`, and so on.
- **Pros**: One naming rule with no exceptions.
- **Cons**: Edits eight GDDs and many criteria for no change in behaviour.
- **Rejection Reason**: Cost with no gain; the six exceptions are listed by name.

## Consequences

### Positive
- One table settles M4: stories build against one name per interface.
- The wiring test covers new signals with no edit, and catches a typo in an allowlist.
- The whole sim graph is readable in `BattleBuilder.build`.
- No result depends on listener order, so S1 can be false without harm.

### Negative
- Adding a signal touches three places: the declaration, this table, and the builder or wrapper.
- Typed records for `SlotState`, `ChipState` and the counters are more code than Dictionaries.
- Six legacy signal names break the past-tense rule.

## Risks
- **S1 (listener order) unsourced.** Mitigation: rule 2.4; every sim signal has one sim listener.
- **S2 (`get_script_signal_list` and `get_signal_connection_list` behaviour) unsourced.** Mitigation: the first wiring-test story proves the test fails on a deliberately unwired fixture signal before it is trusted (a gate that has not been seen to fail is not a gate).
- **S3 (no type check at `emit`).** Mitigation: the per-signal argument-type test.
- **Reference cycles keep an old battle alive after Retry.** Mitigation: declaration rule 7 (no back-references, `HaltLatch`, `Battle.dispose()`); a Retry test checks that the old battle is freed.
- **Table drift from code.** Mitigation: the wiring test reads signals from the scripts, so an undeclared one shows up as unheard; `/architecture-review` checks the table against the GDDs.
- **`DamageEvent` held past a reap.** Mitigation: the listener rule above; the Combat view copies the position it needs.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md | "Wiring is tested, not trusted": every signal has a listener unless on the view allowlist (TR-flow-010) | Section 3: derived set from the script signal list and per-system `VIEW_SIGNALS` |
| game-state-stage-flow.md | Builder wires the battle headless; no autoload | Section 2: builder and wrapper are the only places that connect |
| combat-damage.md | `attack_fired` and `damage_applied` carry copied positions and drive a view only (TR-combat-007) | Declaration rule 2; both on Combat's `VIEW_SIGNALS`; no sim listener |
| battle-hud.md | HUD reads per frame in whole ticks and listens only to allowlisted signals (TR-hud-006) | Reads table returns ticks; HUD listens only to `VIEW_SIGNALS`, wrapper-only and resolver signals |
| tower-system.md | `build`, `upgrade`, `slot_state`, TowerInput signals and `chip_state` | Canonical rows; `chip_state` fields fixed |
| hero-system.md | `pin`, `burst`, reads and counters; HeroInput reads | Canonical rows |
| enemy-wave.md | Wave signals and reads | Canonical rows |
| input-gesture-resolver.md | Resolver signal arguments (`best_tap`, `best_drag`, `press_pos`) | Canonical rows follow the Input GDD |

## Performance Implications
- **CPU**: A signal emit is a direct call per listener; about 1 listener per sim signal. No measurable cost at MVP rates (tens of emits per tick).
- **Memory**: Typed records for reads are created per call; the HUD reads every frame, so `slot_state` and `chip_state` allocate a small object each frame. Acceptable at MVP; if profiling on the phone shows it, the owner caches one record per slot and updates it in place.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
No code exists yet. **These edits are a condition of acceptance and land in the same change that marks this ADR Accepted** (the technical director's condition; GF10 blocks every story until then, so nobody builds from the old names meanwhile).

- `docs/architecture/architecture.md`:
  - 3.2: `attack_fired` goes to CombatView only; add the arguments of `tower_built` and `tower_upgraded`.
  - 4.2: the resolver signals take the Input GDD shape (`pressed(best_tap, best_drag, pos)`, `drag_*(target_id, press_pos, pos)`).
  - 4.3: move `phase`, `lives_changed`, `wave_called_early` and `start_next_wave()` from `Battle` to `StageFlow`; add `StageFlow` reads (`state`, `lives`, `intermission_left`, `result`); add `Battle.dispose()` and the `HaltLatch`.
  - 4.5: `build(slot_index, tower_id)` with the full result codes, `pin(position)`, `burst(aim_point)`, `slot_state -> SlotState`; move `chip_state` to TowerInput with its fields; add Hero's `pin_target`, `burst_state`, `counters`.
  - 4.6: `request_retry()` and `set_call_prompt_done()` on AppRoot.
  - Open Question M4: closed by ADR-0002.
- GDDs:
  - `game-state-stage-flow.md` and `tower-system.md`: `wave_called_early(seconds_left)` becomes `wave_called_early(ticks_left)`, including Flow's worked example (around line 141) and criterion 3 (around line 236, `wave_called_early(0.5)`); Tower's bonus then needs no `to_ticks`.
  - `input-gesture-resolver.md` (around lines 66 and 123): the adapter does not emit `lifecycle_changed`; the BattleWrapper does, with the five states including `back`.
  - `game-state-stage-flow.md`: `lifecycle_changed(state)` comes from the BattleWrapper, not the adapter, and its "Input names it too" note is dropped.
  - `tower-system.md`: define `chip_state()` fields as above.
  - `battle-hud.md`: name the lifecycle signal `lifecycle_changed(state)`; `phase` and `lives_changed` are already on Flow's allowlist, so drop "join".

## Validation Criteria
- The headless wiring test passes on the first battle build, and fails on a fixture system with a deliberately unwired signal.
- The view test passes with the wrapper built.
- The per-signal argument-type tests pass.
- `/architecture-review` finds no interface name that differs between this table, the architecture and the GDDs.

## Related
- Architecture: `docs/architecture/architecture.md` 3.2, 3.5, 4.2 to 4.6; Gate Findings GF2, GF6, GF7, GF8, GF10; Open Question M4.
- Cross-review warning M4: `design/gdd/gdd-cross-review-2026-11-02j.md`.
- ADR-0001 (Accepted): record and ID names.
- Reviews, 2026-11-02: godot-specialist found no blocking issues; nine minor notes folded in (inherited script signals, `String` names, typed dictionaries in 4.4, read-only returns, reference cycles, `waves_complete`). TD-ADR: CONCERNS, nine items; items 1 to 7 revised in this draft (outcome and cancel emit exceptions, the derived wrapper test, StageFlow owns the Flow signals, result codes and A11, the full migration list as a condition of acceptance, at-most-one sim listener, typed wiring variables); items 8 and 9 needed no change.
- Refinement by ADR-0003: commands drain once per frame before the ticks (and inside `tick` for headless callers), instead of only "at the start of the next tick". The decision of this ADR is unchanged.
- Cross-reference to ADR-0004 (Accepted 2026-11-03): its `WiringCheck` implements the section 3 tests. Each system's `snapshot()` is a test-only read. The decision of this ADR is unchanged.
- Cross-reference to ADR-0005 (Accepted 2026-11-03): WaveSim returns a new typed copy per call, and the record field lists are in its section 4. `Combat.attach` and `Combat.report_attack` are direct calls, not signals. The decision of this ADR is unchanged.
- Amended 2026-11-03 by ADR-0008 (user sign-off): rule 7, the builder (not `Battle`) creates the `HaltLatch`; the command table gains `resume() -> int` (`ResumeCommand`); the `lifecycle_changed` row names the AppRoot recipient `AppServices.on_lifecycle` and says `resized` does not pause.
