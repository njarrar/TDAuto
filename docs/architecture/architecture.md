# TowerRiot: Master Architecture

## Document Status
- Version: 1
- Last Updated: 2026-11-02
- Engine: Godot 4.7.2 (pinned 4.7; `Installed at pin time` 4.7.2.stable.official.ed1daf0bf), GDScript, Mobile renderer, Godot Physics 2D (not used by gameplay)
- Run mode: `review_mode full`, `automation autonomous`, `workflow full`, `docs.density thorough`
- GDDs Covered (all 10 design files in `design/gdd/`; the 10 cross-review reports were not re-reviewed):
  `game-concept.md`, `systems-index.md`, and the 8 MVP system GDDs (all at workflow tier `standard`):
  `data-config-pipeline.md`, `input-gesture-resolver.md`, `game-state-stage-flow.md`, `combat-damage.md`,
  `enemy-wave.md`, `tower-system.md`, `hero-system.md`, `battle-hud.md`
- Cross-review state: `design/gdd/gdd-cross-review-2026-11-02j.md`. Blockers L1 to L3 are fixed. Warnings M1 to M11 are carried into
  Open Questions and the Required ADRs below. This run did not re-review the GDDs.
- ADRs Referenced: none exist yet. `docs/architecture/` holds only `tr-registry.yaml` (`requirements: []`). Eight ADRs are required (see Required ADRs).
- Technical Requirements Baseline: 65 requirements, 0 registered, 65 provisional. They are digests of the Detailed Design, Interactions and
  Dependencies sections, not copies of every acceptance criterion. Stories carry the finer detail.
- TD-ARCHITECTURE: 2026-11-02 NOT ASSESSED: the `Agent` tool was not available to the run, so the technical-director gate could not be spawned. Re-run the gate before `/gate-check pre-production`.
- LP-FEASIBILITY: 2026-11-02 NOT ASSESSED: the `Agent` tool was not available to the run, so the lead-programmer gate could not be spawned. Re-run the gate before `/gate-check pre-production`.

---

## Engine Knowledge Gap Summary

Godot 4.7 is past the model's reliable knowledge (about 4.3). Versions 4.5, 4.6 and 4.7 are all HIGH risk in the project's own reference
(`docs/engine-reference/godot/VERSION.md`). The flags below stay in force through the whole document. Where the pinned reference is silent,
this document writes `NOT SOURCEABLE` and does not fill the gap from memory.

### HIGH RISK domains (verify against the engine reference before deciding)

| Domain | What changed or is unknown | Touches |
|---|---|---|
| Input | 4.7: mouse and keyboard events report `InputEvent.DEVICE_ID_MOUSE` and `DEVICE_ID_KEYBOARD`, not device 0. 4.6: touch and mouse focus is separate from keyboard and gamepad focus. **NOT SOURCEABLE:** touch event classes, the `canceled` flag on a touch, `Control` event order against `_input`, and mouse-as-touch emulation are not in `modules/input.md`. | Input & Gesture Resolver, Battle HUD, Hero, Tower |
| UI | 4.7: new projects stretch by default (`canvas_items`, `expand`); existing projects keep their settings. `project.godot` has no `display/window/stretch` keys, so the effective mode must be set on purpose. **NOT SOURCEABLE:** safe-area and notch APIs. | Battle HUD, Input (coordinate space) |
| Core and GDScript | 4.7: an override of a typed method inherits its return type and needs an explicit `return`. Writing one element of a packed array no longer runs the property setter. Lambdas capture locals by value. **NOT SOURCEABLE:** app lifecycle notifications on iOS and Android, `Resource` property validation behaviour, export packing of data files. | Every GDScript module, Data & Config, App Lifecycle |
| Rendering (2D, Mobile) | 4.7: `CanvasItem` lines draw without an antialiasing feather, so tracers look thinner. | Combat view tracers, Hero burst ring, Battle HUD |

### MEDIUM RISK domains

| Domain | Note | Touches |
|---|---|---|
| Animation (Tween) | 4.7 adds `Tween.tween_await()`. Tweens are art only here; no simulation reads one. | Battle HUD, views |
| Audio | 4.7: `area_mask` on `AudioStreamPlayer2D` defaults to 0. Audio is an Alpha system, so no MVP module touches it. | Audio (Alpha) |

### LOW RISK domains

| Domain | Note |
|---|---|
| Physics | Gameplay uses no physics bodies or areas (Flow Rule 4 bans physics areas in simulation). Godot Physics 2D is unchanged since 4.3. |
| Navigation | None. The GDDs drop pathfinding. |
| Networking | None. Single player, no network (analytics dropped). |

### MVP systems that touch HIGH or MEDIUM domains

| System | Domain | Risk |
|---|---|---|
| Input & Gesture Resolver (adapter) | Input | HIGH |
| Game State & Stage Flow | Core and GDScript (lifecycle, main scene, frame loop) | HIGH |
| Data & Config Pipeline | Core and GDScript (Resource format, export) | HIGH |
| Battle HUD & Build UI | UI, Input | HIGH |
| Hero System, Tower System (TowerInput, HeroInput) | Input, Rendering | HIGH |
| Combat & Damage (view), Hero (burst ring) | Rendering 2D lines | HIGH |
| Enemy & Wave | Core and GDScript | HIGH (typed returns, packed arrays) |

---

## System Layer Map

### Decision

The five standard layers apply. Platform is the engine and OS, so no GDD system sits there. The architecture adds two firm rules.

1. **Simulation and view are separate.** All gameplay is plain GDScript objects (`extends RefCounted`) with no scene tree, no `_process`, no
   engine timers and no physics. Views are `Node`s and `Control`s that read the simulation and draw it. This is what lets a whole battle run
   headless for bots and tests (Flow Rules 2 and 4).
2. **Dependencies point down, except the battle builder.** A module may call or read a module in its own layer or a lower one. The one
   exception is the battle builder in Game State & Stage Flow, which constructs and connects modules in every layer above it. It only wires.
   A gameplay branch inside the builder or the scene wrapper is a defect (Flow Rule 3).

### Layer diagram

```
+--------------------------------------------------------------------------------+
| PRESENTATION   Battle HUD & Build UI (Controls, HudField, result, paused)      |
|                Combat view (tracers, flashes)   Stage scene (look only)        |
|                [VS: Menu, Onboarding, VFX]   [Alpha: Audio]                    |
+--------------------------------------------------------------------------------+
| FEATURE        Enemy & Wave      Tower System      Hero System                 |
|                (sim + roster)    (TowerSim+Input)  (HeroSim+Input+Burst)       |
|                [VS: Stage Progression, Skill Points, Skill Tree, Weapons]      |
+--------------------------------------------------------------------------------+
| CORE           Game State & Stage Flow          Combat & Damage                |
|                (app root, builder, tick,        (DamageEvent, Health,          |
|                 phases, lives, wrapper)          Status, helpers, counters)    |
|                [VS: Stat & Modifier Resolution]                                |
+--------------------------------------------------------------------------------+
| FOUNDATION     Data & Config Pipeline          Input & Gesture Resolver        |
|                (catalogue, validator,          (pure resolver + one adapter    |
|                 stat accessor)                  node)                          |
|                [VS: Mobile Platform & Performance, Save/Load]                  |
+--------------------------------------------------------------------------------+
| PLATFORM       Godot 4.7.2 engine API surface, iOS / Android / desktop OS      |
+--------------------------------------------------------------------------------+
```

### Layer assignment

| # | System | Layer | Modules inside it | Engine-facing? |
|---|---|---|---|---|
| 1 | Data & Config Pipeline | Foundation | Catalogue, Validator, StatAccessor | Yes: file loading only |
| 2 | Input & Gesture Resolver | Foundation | GestureResolver (pure), InputAdapter (Node) | Yes: the adapter only |
| 3 | Game State & Stage Flow | Core | AppRoot (Node), BattleBuilder (function), StageFlow (pure), BattleWrapper (Node) | Yes: root and wrapper only |
| 4 | Combat & Damage | Core | DamageEvent, Health, Status, targeting helpers, counters, CombatView | View only |
| 5 | Enemy & Wave | Feature | WaveSim (spawn, move, leak, reap), Roster | No (views read it) |
| 6 | Tower System | Feature | TowerSim (pure), TowerInput (wrapper-built) | TowerInput only |
| 7 | Hero System | Feature | HeroSim (pure), Burst, PinGeometry, HeroInput (wrapper-built) | HeroInput only |
| 8 | Battle HUD & Build UI | Presentation | HudField, BuildArc, StartCall, UpgradeChip drawing, Result, Paused, DebugLog | Yes: Controls |

Layer notes for the three placements that differ from the generic template:

- **Input & Gesture Resolver is Foundation**, as the systems index says. Its resolver is pure and knows no feature. Hero, Tower and the HUD
  register hit targets with it. Input never names a feature system, so a Foundation module does not depend upward.
- **Combat & Damage is Core** and has no code reference to Game State. The GDD lists Flow as "upstream" only because Flow builds and ticks
  it. In code, Combat receives values and has no `import` of Flow, so the layer rule holds.
- **Enemy & Wave is Feature** and also serves `targets()` to Tower and Hero. Those are same-layer reads, allowed.

### Alternatives considered

| Option | Why not |
|---|---|
| A sixth "Composition" layer holding the builder | One function does not justify a layer. It would also make Flow's pure object and the builder sit apart, against Flow Rule 3. |
| An event bus autoload for cross-system signals | Rejected by Flow ("Deliberately not built") and by the injection-over-singletons standard. An unconnected signal must fail a test, which an anonymous bus cannot do. |
| Put the Input resolver in Core beside Flow | The resolver needs only the Input record from Data, and Flow constructs it. Foundation matches the systems index and the GDD quick reference. |

### Engine awareness check

- Foundation and Core modules that touch HIGH risk domains: Data (Resource and export), Input adapter (touch events), Flow (lifecycle, frame
  loop). Each is a required ADR before code (ADR-0001, ADR-0002, ADR-0003).
- No Core or Foundation module touches physics, navigation or networking.

---

## Module Ownership

Format: Owns (sole writer), Exposes, Consumes, Engine APIs. Risk tags are from the Engine Knowledge Gap Summary.

### Foundation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| Catalogue | Every authored record (Tower, Enemy, Wave, Stage, Hero, Burst, Input, Options) | Typed lookups by stable ID, `is_tower(id)`, level counts, Stage and Wave records, Input and Options records | Data files from an explicit manifest | `ResourceLoader` or `FileAccess` (HIGH, NOT SOURCEABLE for export) |
| Validator | The error list `{code, source, record_id, field}` and the all-or-nothing load result | `validate(catalogue) -> Array[Dictionary]` | Catalogue records, field domain table | None |
| StatAccessor | The vocabulary of stat keys and their types | `get_int(ctx, key)`, `get_float(ctx, key)` | Catalogue, read context (`def_id`, level, optional live entity) | None |
| GestureResolver | Target registry, one active pointer, the four-state machine, gesture log | Signals `pressed`, `tap`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `ground_tap`, `idle`; calls `register`, `unregister`, `cancel`, `cancel_pointer` | Input record | None (pure) |
| InputAdapter | Translation of engine events into the five resolver calls, lifecycle signal | `lifecycle_changed(state)`; owns the press-to-release guarantee | `GestureResolver`, engine input events | `Node._input`, touch and mouse events (HIGH, NOT SOURCEABLE), `Control.mouse_filter` (HIGH) |

### Core

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| AppRoot | Catalogue lifetime, launch ID, `attempt_seq`, `call_prompt_done`, the fatal screen, the Retry latch | `fatal(cause)`, `request_retry()`, `set_call_prompt_done()` | Catalogue load result | `Node` main scene, `queue_free` or `free` (HIGH, timing unverified) |
| BattleBuilder | Construction and signal connection of one battle | `build(catalogue, stage_id, seed, fatal_handler) -> Battle` | Every battle system | None (pure function) |
| StageFlow | Phases, lives, outcome latch, `halted()`, `intermission_left`, `to_ticks` | `tick(dt)`, `start_next_wave()`, `phase`, `lives_changed`, `wave_called_early(seconds_left)`, `in_build()`, result | Wave signals, Stage record | None |
| BattleWrapper | Tick accumulator and clamp, adapter, views, HeroInput, TowerInput | none outward | Battle, engine frame | `Node._process`, `_notification` (HIGH, NOT SOURCEABLE) |
| Combat | Health and Status per enemy, all HP changes, per-source counters | `deliver(event)`, `apply_slow`, `speed_factor`, `is_dead`, `hp_left`, `first_in`, `nearest_in`, `all_in_radius`, `attack_fired`, `damage_applied` | Positions and values passed in | None |

### Feature

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| WaveSim | Roster, `spawn_id`, wave index, schedule, leaks, reap, `got_through_by_type` | `start_next_wave()`, `roster()`, `targets()`, `wave_index()`, `enemy_killed(bounty)`, `enemy_leaked(lives_cost)`, `wave_cleared(intermission_duration)`, `waves_complete` | Stage and Wave records, StatAccessor, Combat state | None |
| TowerSim | Gold, slot states, tower instances, attack timers | `build(slot, role)`, `upgrade(slot)`, `gold()`, `slot_state(i)`, `chip_state()`, `gold_changed`, `tower_built`, `tower_upgraded` | `enemy_killed`, `targets()`, `slot_positions`, Combat API, StatAccessor | None |
| TowerInput | Slot and tower registration, the upgrade chip window | `slot_tapped(slot_index)`, `tower_inspected(slot_index)`, `upgrade_refused(slot_index)` | GestureResolver, TowerSim commands | Real-time clock for the chip (`Time` singleton, LOW) |
| HeroSim | Position, pin, leash, burst state, cooldown, counters | `pin(pos)`, `burst(aim)`, `position()`, `pin_state()`, `burst_state()`, `cooldown_left()`, `hero_target_id()`, `hero_pinned`, `burst_started` | `targets()`, Combat API, StatAccessor, Stage record, Options | None |
| HeroInput | Hero, burst button and sink registration; aim and cancel hysteresis; aim-point offset | none outward | GestureResolver, HeroSim commands | None |

### Presentation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| Battle HUD | Presentation state only: arc, Start/Call arming, prompts, rejection ring, result text, paused overlay, human debug log | none | Reads of Tower, Hero, Wave, Flow, Combat; signals listed in Data Flow | `Control`, `CanvasLayer`, `_draw`, `Tween` (UI HIGH, Animation MEDIUM), safe area (NOT SOURCEABLE) |
| Combat view | Tracer lines and flashes | none | `attack_fired`, `damage_applied` | `CanvasItem.draw_line` (Rendering HIGH: thinner lines in 4.7) |
| Stage scene | Field hue, base value, grid tilt (look only) | none | Stage `scene_ref` | `PackedScene.instantiate()` (LOW) |

### Dependency diagram (code references, arrows point to what is used)

```
 Battle HUD ----reads----> Tower, Hero, Wave, Flow, Combat(counters)
     |   \                      ^      ^      ^
     |    registers             |      |      |
     v                          |      |      |
 GestureResolver <--registers-- TowerInput  HeroInput      (wrapper-built, absent headless)
     ^                          |             |
     |                       TowerSim       HeroSim
 InputAdapter                     \           /
                                   \         /
                          WaveSim --+-- Combat <-- Status, Health
                              |
                         StatAccessor --> Catalogue --> Validator

 BattleBuilder (in Flow) constructs and connects everything above. It is the only upward reference.
 AppRoot holds Catalogue and rebuilds the battle on Retry.
```

### Ownership rules that the ADRs and control manifest must keep

1. **Combat is the only writer of HP.** Nothing else changes HP (Combat Rule 2).
2. **Wave is the only writer of the roster.** Readers get read-only lists valid for their own tick slot only.
3. **Tower owns gold. Flow owns lives.** Nobody else writes either.
4. **Data owns no behaviour and emits no signals.** Each emitter declares its own signals (Data GDD, Not owned).
5. **Views hold no gameplay state.** Retry rebuilds them.
6. **Dealer and grantor are separate fields.** `source_kind` and `source_id` name the dealer. A future modifier's grantor gets its own field.

---

## Data Flow

Single-threaded. No path crosses a thread boundary. Gameplay uses no `await`, no engine timers and no `_process` (Flow Rule 4).

### 3.1 Frame update path

```
engine frame
  |
  v
InputAdapter._input(event)  ---- 5 calls ---->  GestureResolver  --signals-->  HeroInput / TowerInput / Battle HUD
  |                                                                                  |
  |                                              commands (pin, burst, build, upgrade, Start/Call) apply here,
  |                                              BETWEEN ticks, on the input call stack
  v
BattleWrapper._process(delta)
  accumulate real time, clamp, then for each owed tick:
      battle.tick(dt):
        halted()? stop
        1. StageFlow (phase clock, intermission countdown)
        2. WaveSim advance   (spawn, move, leak)             leaks resolve before fire
        3. Status countdown  (Combat, given WaveSim roster)
        4. TowerSim by slot index
        5. HeroSim, then burst
        6. WaveSim reap      (kills, bounty, clear checks)
  |
  v
views redraw from reads (roster(), position(), cooldown_left(), counters)
```

Whether input handling really runs before ticks in a frame is **unverified** (Battle HUD Rule 18, Combat open question). ADR-0006 must settle it against live 4.7 docs and a phone run.

### 3.2 Event and signal path

| Data | Producer | Consumer | Kind |
|---|---|---|---|
| `enemy_killed(bounty: int)` | WaveSim (reap) | TowerSim (gold) | Signal, synchronous, wired in builder |
| `enemy_leaked(lives_cost: int)` | WaveSim (leak) | StageFlow (lives) | Signal, synchronous, before `waves_complete` |
| `wave_cleared(intermission_duration: float)`, `waves_complete` | WaveSim | StageFlow | Signal |
| `wave_called_early(seconds_left)` | StageFlow | TowerSim (bonus gold) | Signal |
| `phase(state)`, `lives_changed(current)` | StageFlow | Battle HUD, TowerInput (chip) | Signal (view allowlist) |
| `gold_changed`, `tower_built`, `tower_upgraded` | TowerSim | Battle HUD | Signal (view allowlist) |
| `hero_pinned(position)`, `burst_started(aim_point, telegraph_ticks)` | HeroSim | Battle HUD | Signal (view allowlist) |
| `attack_fired(...)`, `damage_applied(event, applied, position)` | Combat | CombatView, Battle HUD | Signal, copied positions (view allowlist) |
| `slot_tapped`, `tower_inspected`, `upgrade_refused` | TowerInput | Battle HUD | Signal, wrapper only |
| `lifecycle_changed(state)` | InputAdapter | StageFlow (pause), HUD | Signal |
| Reads (`gold()`, `slot_state`, `chip_state`, `roster()`, `position()`, `pin_state()`, `cooldown_left()`, `wave_index()`, counters) | Owners | Battle HUD, views, bots | Synchronous read, every frame, compared in whole ticks |

Every connection is written in `BattleBuilder` as an explicit typed `signal.connect(callable)`, so the GDScript parser catches a misspelt name.
One test fails if any signal of any battle system has no listener, unless it is on the named view allowlist (Flow, "Wiring is tested, not trusted").

### 3.3 Save and load path

There is none at MVP. Nothing persists: an app killed by the OS loses the stage (Flow Rule 17). The only file the game writes is the human debug
log (Battle HUD Rule 19), which is development tooling. Save/Load is a Vertical Slice system. The seam is already fixed by the systems index:
progression systems expose `to_dict()` and `from_dict()` with a version field and never call Save; Save injects loaded state at boot. Data keeps
stable IDs and a retired-ID list for it. A Save/Load ADR is deferred to that tier.

### 3.4 Initialisation order

```
1. Engine starts main scene = AppRoot (no autoloads, no gameplay references)
2. AppRoot loads Catalogue (Data), validates all records, collects all errors
       fail  -> Fatal screen (uses no catalogue data), absorbing
       ready -> holds Catalogue for the whole session
3. AppRoot starts InStage: BattleWrapper (scene) calls BattleBuilder.build(catalogue, stage_id, seed, fatal_handler)
       a. GestureResolver (with Input record), then Combat, WaveSim, TowerSim, HeroSim, StageFlow
       b. all signal connections
       c. wrapper loads the stage scene by `scene_ref`, then InputAdapter, views, HeroInput, TowerInput, Battle HUD
4. StageFlow emits phase(Build) once: after views connect (with views), or when build returns (headless)
5. Clock stays stopped until the player taps Start Wave
```

### 3.5 Retry path

`Retry` tap sets a latch on AppRoot. The root's frame acts on it: stop the clock, cancel input inline, free the old battle and its views at
once, build a new battle, new resolver, new adapter, new views. It runs between ticks and never inside a signal. Only the root, its counters
(`launch ID`, `attempt_seq`, `call_prompt_done`) and the Catalogue survive. The timing of `free()` is unverified (ADR-0003).

### 3.6 Fatal path

The failure handler is idempotent and keeps the first cause. It latches the battle and the root. `halted()` turns true at once, the tick loop
skips the remaining slots, the clock stops after the tick returns, and nothing persists. GDScript has no exceptions, so the calling function still
finishes; every system checks `halted()` after each accessor read and each signal.

---

## API Boundaries

Pseudocode is GDScript. Names follow `project.yaml` (`PascalCase` classes, `snake_case` members, past-tense signals). Engine types used in an
interface are flagged. Where two GDDs spell one name differently (warning M4) the form below is the proposed canonical one and the GDD fix is
tracked in Open Questions.

### 4.1 Data and stat accessor (Foundation)

```gdscript
class_name Catalogue extends RefCounted
# Read-only after load. No setters. No fallbacks.
func tower(def_id: StringName) -> Dictionary        # or typed record; format is ADR-0001
func stage(stage_id: StringName) -> Dictionary
func wave(wave_id: StringName) -> Dictionary
func is_tower(def_id: StringName) -> bool
func level_count(def_id: StringName) -> int

class_name StatAccessor extends RefCounted
# Invariant: a level passed for an Enemy, Hero or Burst is a bad call.
# Invariant: unknown key fails here. Returns the type the key table declares.
func get_float(ctx: ReadContext, key: StringName) -> float
func get_int(ctx: ReadContext, key: StringName) -> int

class_name ReadContext extends RefCounted
var def_id: StringName
var level: int          # Towers only
var entity: Object      # optional live entity; a HUD cost preview passes none
```

Guarantees: every error carries `{code, source, record_id, field}`; the game does not start with an invalid catalogue; tests build fixture
catalogues in code with no file I/O. Engine-type flag: if records are typed `Resource` subclasses, a missing field may silently take a default
(Data GDD). **NOT SOURCEABLE** from the pinned reference, so ADR-0001 must test it on 4.7.2.

### 4.2 Input resolver and adapter (Foundation)

```gdscript
class_name GestureResolver extends RefCounted
signal pressed(target_id: int, pos: Vector2)
signal tap(target_id: int, pos: Vector2)
signal drag_started(target_id: int, pos: Vector2)
signal drag_moved(target_id: int, pos: Vector2)
signal drag_ended(target_id: int, pos: Vector2)
signal drag_cancelled(target_id: int)
signal ground_tap(pos: Vector2)
signal idle()

func register(owner_tag: StringName, shape: Dictionary, priority: int, gestures: int) -> int
func unregister(target_id: int) -> void
func press(index: int, pos: Vector2) -> void
func move(index: int, pos: Vector2) -> void
func release(index: int, pos: Vector2) -> void
func cancel_pointer(index: int) -> void
func cancel() -> void        # host-driven only; resolver has no cancel gesture

class_name InputAdapter extends Node
signal lifecycle_changed(state: StringName)   # focus lost, focus gained, quit requested, resized
```

Invariants for callers: owners register themselves, the resolver never names a feature, and one press yields exactly one tap, one drag or nothing,
delivered to one target. **Adapter contract (binding):** every `press` the adapter forwards is followed by exactly one `release`, one
`cancel_pointer` or one `cancel()` of that index, whatever Controls lie under the drag and whatever the OS does. The adapter checks a touch's
`canceled` flag before treating it as a release. Engine-type flags: touch event classes, `canceled`, and event delivery past a
`mouse_filter = STOP` Control are **NOT SOURCEABLE** (HIGH). Mouse events must be told apart by event class, not `device == 0` (4.7).

### 4.3 Battle builder and flow (Core)

```gdscript
class_name BattleBuilder extends RefCounted
static func build(catalogue: Catalogue, stage_id: StringName, seed: int,
		fatal_handler: Callable) -> Battle    # no scene, no real time; bots and tests call this

class_name Battle extends RefCounted
func tick(dt: float) -> void                  # the only way simulation time enters
func halted() -> bool
func in_build() -> bool
func start_next_wave() -> void                # Start/Call
signal phase(state: StringName)
signal lives_changed(current: int)
signal wave_called_early(seconds_left: float)
```

Guarantees: commands run between ticks only; the same stage, seed and command script give the same result; `to_ticks(seconds)` is the one
float-to-tick conversion. A Fatal inside `build` discards the partial battle (see warning M2 in Open Questions).

### 4.4 Combat (Core)

```gdscript
class_name DamageEvent extends RefCounted
var target: Object
var amount: float
var source_kind: int        # TOWER, HERO, BURST
var source_id: StringName   # dealer's definition ID

class_name Combat extends RefCounted
func deliver(event: DamageEvent) -> float          # returns applied; runs inside a tick only
func apply_slow(enemy: Object, strength: float, seconds: float) -> void
func speed_factor(enemy: Object) -> float
func is_dead(enemy: Object) -> bool
func hp_left(enemy: Object) -> float
func first_in(list: Array, ...) -> Object          # tie break: lowest spawn_id; skips the dead
func nearest_in(list: Array, from: Vector2, range: float) -> Object
func all_in_radius(list: Array, center: Vector2, radius: float) -> Array
signal attack_fired(source_kind, source_id, origin, impact, radius)
signal damage_applied(event, applied, position)    # positions are copies; the target may be reaped
```

Guarantees: only the HP remaining counts toward the counters; a dead enemy takes and counts nothing; slow is one slot, whole ticks.

### 4.5 Wave, Tower, Hero (Feature)

```gdscript
# WaveSim
func roster() -> Array      # read-only, valid for the reader's own tick slot
func targets() -> Array     # roster limited to enemies whose centre is inside the field (0..540, 0..960)
func wave_index() -> int
func got_through_by_type() -> Dictionary
signal enemy_killed(bounty: int)
signal enemy_leaked(lives_cost: int)
signal wave_cleared(intermission_duration: float)
signal waves_complete()

# TowerSim (also the bots' commands)
func build(slot_index: int, role_tag: StringName) -> int    # result enum: OK, NO_GOLD, ...
func upgrade(slot_index: int) -> int
func gold() -> int
func slot_state(slot_index: int) -> Dictionary
func chip_state() -> Dictionary    # fields undefined in the Tower GDD (warning M4); define in the Tower stories

# HeroSim
func pin(pos: Vector2) -> int      # HALTED, BAD_POSITION, OUT_OF_BOUNDS, BUTTON_ZONE, OK
func burst(aim: Vector2) -> int    # HALTED, BUILD_PHASE, NOT_PINNED, NOT_READY, BAD_POSITION, OFF_FIELD, OUT_OF_REACH, OK
```

Invariants: leak events fire synchronously and before `waves_complete`; `halted()` is checked after every accessor read and every signal; no
system holds a target between attacks (re-pick every attack, so no reference dangles); a burst is refused in Build.

### 4.6 Battle HUD (Presentation)

The HUD exposes nothing. It calls `Battle.start_next_wave()`, `TowerSim.build()`, the Retry latch on AppRoot, `set_call_prompt_done()` on AppRoot,
and listens to the signals in Data Flow 3.2. Invariants: modal screens are full-screen Controls that consume every event before the adapter sees
it; all commands run from the input call stack before the frame's ticks; Retry only sets a latch.

### 4.7 Engine type check (Phase 4 awareness)

| Type used in an interface | Where | Version note |
|---|---|---|
| `RefCounted`, `Node`, `Control`, `Callable`, `signal` | all | In training data, LOW |
| `StringName`, typed `Array`, `Dictionary` | all | LOW. 4.7 typed-return override rule applies to subclasses that override a typed method |
| `InputEventScreenTouch`, `InputEventScreenDrag`, `InputEventMouseButton`, `InputEventMouseMotion` | InputAdapter | **NOT SOURCEABLE** in the pinned reference (HIGH domain) |
| `InputEvent.DEVICE_ID_MOUSE` | InputAdapter | 4.7, confirmed in `breaking-changes.md` |
| `CanvasItem.draw_line` | CombatView, HUD | 4.7: no antialiasing feather |
| `Tween` | HUD | `tween_await()` new in 4.7; avoid in simulation |
| `DisplayServer` safe-area call | HUD | **NOT SOURCEABLE** |

---

## ADR Audit

### Existing ADRs

None. `docs/architecture/` holds no `adr-*.md` files. The ADR quality check (engine compatibility, version, post-cutoff flags, GDD linkage,
conflicts, validity) has nothing to check. This is recorded as a result, not a pass.

| ADR | Engine Compat | Version | GDD Linkage | Conflicts | Valid |
|---|---|---|---|---|---|
| (none exist) | n/a | n/a | n/a | n/a | n/a |

### Traceability coverage

Of 65 provisional requirements, **0 are covered** by an accepted ADR and **65 are gaps**. Every gap maps to a Required ADR below. The mapping
column in the Technical Requirements Baseline names the ADR that will cover it. `/architecture-review` registers the IDs and builds the matrix.

| Required ADR | Requirements it will cover |
|---|---|
| ADR-0001 | TR-data-001 to 008 |
| ADR-0002 | TR-input-001 to 008, TR-hud-004 (partly) |
| ADR-0003 | TR-flow-001, 002, 005 to 009 |
| ADR-0004 | TR-flow-010, TR-combat-007, TR-hud-006 |
| ADR-0005 | TR-combat-001 to 006, TR-enemy-001 to 008 |
| ADR-0006 | TR-flow-003, 004, TR-tower-005, TR-hero-008, TR-hud-003 |
| ADR-0007 | TR-hud-001, 002, 004, 005, 007, 008, TR-input-006 |
| ADR-0008 | TR-flow-011, TR-tower-007, TR-hero-005 |
| Stories only (no ADR) | TR-tower-001 to 004, 006, TR-hero-001 to 004, 006, 007 |

---

## Technical Requirements Baseline

Extracted from 10 design GDDs (8 system GDDs plus the concept and the systems index; the 10 cross-review reports were used only for the open items)
| 65 total requirements | 0 registered, 65 provisional (TR registry: read, 0 entries, `requirements: []`). IDs come from
`bash .claude/scripts/registry.sh next-id tr <system>`, which gave `001` for every system. They are **provisional**: do not cite them as permanent
until `/architecture-review` registers them. No GDD contributed nothing; the concept contributed the performance targets (TR-hud-008).

| Req ID | GDD | Requirement | Domain | ADR |
|---|---|---|---|---|
| TR-data-001 (provisional) | data-config-pipeline | Catalogue of typed records (Tower, Enemy, Wave, Stage, Hero, Burst, Input, Options), each with a stable lowercase snake_case ID and a non-empty rationale | Core | 0001 |
| TR-data-002 (provisional) | data-config-pipeline | Load once from an explicit file manifest (no directory scan); either every record is valid or the game does not start | Core | 0001 |
| TR-data-003 (provisional) | data-config-pipeline | Validate all fields against domain tables and collect every error as `{code, source, record_id, field}`; no fallbacks in any build | Core | 0001 |
| TR-data-004 (provisional) | data-config-pipeline | The format must detect a missing field, a fractional integer and an unknown property, or an added check must | Core | 0001 |
| TR-data-005 (provisional) | data-config-pipeline | Definitions are read-only after load; mutable state lives on runtime instances holding `def_id` (and level for towers) | Core | 0001 |
| TR-data-006 (provisional) | data-config-pipeline | One stat accessor `(read context, key)` returning the declared type; the base value at MVP, with modifiers slotting in later at no call-site change | Core | 0001 |
| TR-data-007 (provisional) | data-config-pipeline | Catalogue is injected by the app root and builder; no autoload; tests build fixture catalogues in code | Core | 0001 |
| TR-data-008 (provisional) | data-config-pipeline | Catalogue loads from an Android and iOS export with no path or packing assumption; edit-to-run in about 10 s on desktop; stage geometry (`path_points`, `slot_positions`) has a defined storage form | Core | 0001 |
| TR-input-001 (provisional) | input-gesture-resolver | Resolver is a pure object with no scene-tree dependency: registry, one active pointer, four-state machine, five input calls | Input | 0002 |
| TR-input-002 (provisional) | input-gesture-resolver | Each press yields exactly one tap, one drag or nothing, delivered to exactly one target by priority; owners register themselves | Input | 0002 |
| TR-input-003 (provisional) | input-gesture-resolver | Adapter guarantees every forwarded press ends in exactly one release, `cancel_pointer` or `cancel()` across Controls and OS touch-cancel | Input | 0002 |
| TR-input-004 (provisional) | input-gesture-resolver | Desktop mouse maps to one touch pointer; one physical press gives one gesture; events identified by class, not device 0 | Input | 0002 |
| TR-input-005 (provisional) | input-gesture-resolver | Hit radii and tap/drag slop meet the 44 pt / 48 dp minimum; at most 5% misses and zero mis-fires over 20 attempts on a phone | Input | 0002 |
| TR-input-006 (provisional) | input-gesture-resolver | Gesture coordinate space stays fixed for a gesture's life; resize or restretch cancels it; reference field 540 by 960; below 360 dp unsupported | UI | 0007 |
| TR-input-007 (provisional) | input-gesture-resolver | Adapter emits `lifecycle_changed(state)` for focus lost, focus gained, quit requested and resized | Core | 0002 |
| TR-input-008 (provisional) | input-gesture-resolver | Gesture log records each gesture, including the landed pin position for a hero drag (fix L3) | Input | 0002 |
| TR-flow-001 (provisional) | game-state-stage-flow | Minimal app root, no autoload, holds catalogue, fatal screen, launch ID, `attempt_seq` and `call_prompt_done` across Retry | Core | 0003 |
| TR-flow-002 (provisional) | game-state-stage-flow | `build(catalogue, stage_id, seed, fatal_handler)` is a plain function with explicit signal connections and no scene, so bots run headless | Core | 0003 |
| TR-flow-003 (provisional) | game-state-stage-flow | Simulation time enters only through `battle.tick(dt)` at a fixed 60 ticks per second with a clamped accumulator; no `_process`, timers, `await` or wall clock in gameplay | Core | 0006 |
| TR-flow-004 (provisional) | game-state-stage-flow | Fixed system tick order; commands only between ticks; same stage, seed and script give an identical result | Core | 0006 |
| TR-flow-005 (provisional) | game-state-stage-flow | Phase machine Build, Wave, Intermission, Paused, Won, Lost, Fatal with `phase` emitted on every change and once per built battle | Core | 0003 |
| TR-flow-006 (provisional) | game-state-stage-flow | Flow owns lives and the outcome; the outcome latches in two steps (`halted()` mid-tick, clock stop after); a tie is a loss | Core | 0003 |
| TR-flow-007 (provisional) | game-state-stage-flow | Retry rebuilds the whole battle, resolver, adapter and views; a latch on the root defers it to between ticks | Core | 0003 |
| TR-flow-008 (provisional) | game-state-stage-flow | Focus loss or backgrounding enters Paused; accumulator zeroed on resume; a tap resumes; quit and resize are handled (M1) | Core | 0003 |
| TR-flow-009 (provisional) | game-state-stage-flow | Fatal handler is idempotent and keeps the first cause; the fatal screen loads without catalogue data | Core | 0003 |
| TR-flow-010 (provisional) | game-state-stage-flow | Wiring test: every signal of every battle system has a listener unless on the named view allowlist | Core | 0004 |
| TR-flow-011 (provisional) | game-state-stage-flow | Authored durations become whole ticks through one `to_ticks` conversion; tests can snapshot a battle, enumerate its systems and inject recording ones | Core | 0008 |
| TR-combat-001 (provisional) | combat-damage | All damage enters through `deliver(event)`, one event per victim, only inside a tick; nothing else changes HP | Core | 0005 |
| TR-combat-002 (provisional) | combat-damage | Only HP actually removed counts; per-source counters (`dealt[source_id]` with kind) stay readable after the outcome | Core | 0005 |
| TR-combat-003 (provisional) | combat-damage | All hits are instant (no projectiles); splash and burst victims are computed at release from current positions | Core | 0005 |
| TR-combat-004 (provisional) | combat-damage | One slow slot per enemy in whole ticks; stronger replaces, equal keeps longer, weaker ignored; `speed_factor` read by Wave | Core | 0005 |
| TR-combat-005 (provisional) | combat-damage | Pure targeting helpers `first_in`, `nearest_in`, `all_in_radius` over a caller list; ties by lowest `spawn_id`; skip the dead | Core | 0005 |
| TR-combat-006 (provisional) | combat-damage | Health and Status attach to an enemy instance; Combat reads no catalogue (`max_hp` passed at spawn) | Core | 0005 |
| TR-combat-007 (provisional) | combat-damage | `attack_fired` and `damage_applied` carry copied positions and drive a small view; nothing in gameplay depends on them | Rendering | 0004 |
| TR-enemy-001 (provisional) | enemy-wave | One continuous path per stage; stage geometry (`path_points`, `slot_positions`, `path_width`) is data on the Stage record | Core | 0005 |
| TR-enemy-002 (provisional) | enemy-wave | Waves are authored with no randomness; spawn ticks computed from wave start on an absolute schedule; battle-wide `spawn_id` | Core | 0005 |
| TR-enemy-003 (provisional) | enemy-wave | Speed read through the accessor each use, times `speed_factor`; one position per enemy per tick, cached | Core | 0005 |
| TR-enemy-004 (provisional) | enemy-wave | Leaks fire synchronously in `spawn_id` order, before `waves_complete`; a fatal leak stops the loop | Core | 0005 |
| TR-enemy-005 (provisional) | enemy-wave | Reap step in the tick: kills in `spawn_id` order emit `enemy_killed(bounty)`; clear check runs every tick while a wave is active | Core | 0005 |
| TR-enemy-006 (provisional) | enemy-wave | `roster()` and `targets()` are read-only lists valid in the reader's slot; an enemy is targetable only while its centre is inside the field | Core | 0005 |
| TR-enemy-007 (provisional) | enemy-wave | At most 48 enemies alive at once (`peak_alive_ub`); views pool enemy nodes | Rendering | 0007 |
| TR-enemy-008 (provisional) | enemy-wave | Content test enforces layout rules L1 to L13 and wave rules on real data; checks run in CI, not at boot | Core | 0001 |
| TR-tower-001 (provisional) | tower-system | TowerSim (pure, built by the builder) and TowerInput (wrapper-built, absent headless) are separate objects | Core | stories |
| TR-tower-002 (provisional) | tower-system | Gold changes only through `enemy_killed(bounty)`, build, upgrade and the early-call bonus; one `build` and `upgrade` command shared by the arc and the bots | Core | stories |
| TR-tower-003 (provisional) | tower-system | Three roles (single target, splash, slow) fire in slot-index order, first along the path; two levels, no selling | Core | stories |
| TR-tower-004 (provisional) | tower-system | Early-call bonus computed from `seconds_left` and `early_call_seconds_per_gold`, never from burst state | Core | stories |
| TR-tower-005 (provisional) | tower-system | The upgrade chip needs real time while the clock is stopped; hard bounce guard of at least 200 ms before a commit tap; input order against the real-time feed | Input | 0006 |
| TR-tower-006 (provisional) | tower-system | Tower exposes `gold()`, `slot_state`, `chip_state`, `gold_changed`, `tower_built`, `tower_upgraded` for the HUD | UI | stories |
| TR-tower-007 (provisional) | tower-system | Tower CI computes `peak_alive_ub` and layout rule L10 and runs in a headless battle | Core | 0008 |
| TR-hero-001 (provisional) | hero-system | HeroSim (pure) and HeroInput (wrapper-built) are separate; the hero has no HP at MVP | Core | stories |
| TR-hero-002 (provisional) | hero-system | Pin sets a destination inside `pin_rect` and outside `pin_exclusion`; straight-line walk at `walk_speed`; leash is the whole reach | Core | stories |
| TR-hero-003 (provisional) | hero-system | Burst is drag-only from the button; aim point is finger plus (0, -100) clamped to reach; cancel hysteresis 64 out and 48 back; refused in Build | Input | stories |
| TR-hero-004 (provisional) | hero-system | Burst telegraph and release run in the Hero-and-burst tick slot with victims computed at release; cooldown runs from release | Core | stories |
| TR-hero-005 (provisional) | hero-system | Bots drive `pin` and `burst` through the builder; one equivalence test passes through the resolver; counters give kills per burst and hero share | Core | 0008 |
| TR-hero-006 (provisional) | hero-system | Hero exposes `position()`, `pin_state()`, `burst_state()`, `cooldown_left()`, `hero_target_id()`, `hero_pinned`, `burst_started` | UI | stories |
| TR-hero-007 (provisional) | hero-system | `left_hand` and `reduce_motion` read from the Options record; the burst button mirrors by hand | UI | stories |
| TR-hero-008 (provisional) | hero-system | HeroInput sits in the wrapper; input is handled against the view's per-frame centre update (hero hit disc follows the walking hero) | Input | 0006 |
| TR-hud-001 (provisional) | battle-hud | Modal result and Paused screens are full-screen Controls that consume events before the adapter; the HUD holds no gameplay state | UI | 0007 |
| TR-hud-002 (provisional) | battle-hud | Build arc, Start/Call disc, upgrade chip and rejection ring register with the resolver at set priorities (arc discs TAP 300, backdrop TAP 250, Start/Call TAP 350) | Input | 0007 |
| TR-hud-003 (provisional) | battle-hud | All commands run from the input call stack before the frame's ticks; Retry's handler only sets a latch (destroying its own caller is unsafe) | Core | 0006 |
| TR-hud-004 (provisional) | battle-hud | Layout anchors to safe areas and notches; tap targets at least 44 pt / 48 dp; portrait 540 by 960 reference | UI | 0007 |
| TR-hud-005 (provisional) | battle-hud | Human debug log writes per-attempt and per-wave records, a Fatal record and a provisional record on quit, with `call_prompt_shown` stamped (L1) | Core | 0007 |
| TR-hud-006 (provisional) | battle-hud | HUD reads values per frame, comparing whole ticks, and listens only to signals on the view allowlist | UI | 0004 |
| TR-hud-007 (provisional) | battle-hud | Start/Call arms over 300 ms of real time; `call_prompt_done` is set on the app root on the first call after the prompt shows (L2) | UI | 0007 |
| TR-hud-008 (provisional) | game-concept, battle-hud | 60 fps on a mid-range phone (30 floor on low-end Android), 16.6 ms frame, at most 60 draw calls, 256 MB memory, textures at most 16 MB | Rendering | 0007 |

---

## Required ADRs

No ADR exists. These eight are required. IDs are the next free numbers. Foundation first. Each ADR must record the engine version (4.7.2),
flag post-cutoff APIs, and list the TR-IDs it covers in "GDD Requirements Addressed".

### Must have before coding starts (Foundation and Core)

| ADR | Layer | Decision to make | Covers | Engine risk |
|---|---|---|---|---|
| **ADR-0001 Catalogue Storage Format and Stat Accessor** | Foundation | Storage format (typed Godot Resources recommended, JSON as fallback); how a missing field, fractional integer and unknown property are detected; read-only enforcement; accessor signature and key format; file locations; storage form of `path_points` and `slot_positions`; export check on Android and iOS | TR-data-001 to 008, TR-enemy-008 | HIGH: Resource defaults, export packing NOT SOURCEABLE |
| **ADR-0002 Input Adapter and Gesture Path** | Foundation | Which Godot input path feeds the adapter (`_unhandled_input` versus Control `_gui_input`); how moves and releases of the active touch survive a `mouse_filter = STOP` Control; touch-cancel handling; desktop mouse as touch; `lifecycle_changed` sources; tablet slop | TR-input-001 to 005, 007, 008 | HIGH: touch events NOT SOURCEABLE; verify against live 4.7 docs |
| **ADR-0003 App Lifecycle and Battle Composition** | Core | Main scene; app root; builder ownership and lifetime; retry teardown including views and `free()` timing; pause mechanism; which lifecycle notifications fire on iOS and Android; guarantee that the fatal scene loads; Fatal during or after `build` (M2); quit and resize handling (M1) | TR-flow-001, 002, 005 to 009 | HIGH: lifecycle NOT SOURCEABLE; needs a phone run |
| **ADR-0004 Signal Contracts and Wiring Conventions** | Foundation | Typed signal declarations, explicit connections in the builder, no event-bus autoload, the view allowlist and how the wiring test derives its set, canonical interface names (M4) | TR-flow-010, TR-combat-007, TR-hud-006 | MEDIUM: lambda capture by value, GDScript 4.7 typing |
| **ADR-0005 Simulation State Attachment: Health, Status and Roster** | Core | How Health and Status attach to an enemy instance; whether a future spawner sits behind `deliver`; roster and `spawn_id` representation; the technical director's open call on cutting ProjectileSpawner and the tick order | TR-combat-001 to 006, TR-enemy-001 to 006 | LOW to MEDIUM (typed arrays, packed array write rule) |
| **ADR-0006 Frame Order: Input, Ticks and View Update** | Core | Tick rate, accumulator and clamp; whether input handling runs before the ticks in a frame; where TowerInput and HeroInput sit in the wrapper; input against the real-time chip feed and the per-frame hero centre update | TR-flow-003, 004, TR-tower-005, TR-hero-008, TR-hud-003 | HIGH: frame order unverified |
| **ADR-0008 Headless Battle Harness and Snapshot** | Foundation | How tests snapshot a battle, enumerate its systems and inject recording ones; bot commands through the builder; gdUnit4 on 4.7.2 | TR-flow-011, TR-tower-007, TR-hero-005 | LOW: gdUnit4 6.2.2 runs on 4.7.2 per the reference |

### Should have before the relevant system is built

| ADR | Layer | Decision | Covers |
|---|---|---|---|
| **ADR-0007 Battle HUD Layering, Safe Area and Stretch** | Presentation | Control layering above the adapter; modal consumption; the Paused resume input route (M6); stretch mode and aspect (set `display/window/stretch` on purpose); safe-area API (NOT SOURCEABLE); Control event order against the adapter; enemy and effect pooling; renderer check (Mobile versus Compatibility on low-end Android) | TR-hud-001, 002, 004, 005, 007, 008, TR-input-006, TR-enemy-007 |

### Can defer to implementation or a later tier

| Topic | Tier |
|---|---|
| Save/Load schema and versioning | Vertical Slice |
| Stat & Modifier resolver internals behind the accessor | Vertical Slice |
| Mobile Platform & Performance (export presets, device budgets) | Vertical Slice |
| Audio bus and `area_mask` handling | Alpha |
| Particle and VFX technique for the burst ring | With Visual Feedback & VFX |

---

## Architecture Principles

1. **Simulation is plain objects, views are nodes.** No gameplay reads a scene, a timer or the wall clock. A battle runs headless, so bots and
   tests measure the game (Pillar 2's hero share must be answerable from the first build).
2. **One way in for time, one way in for damage, one way in for stats.** `battle.tick(dt)`, `deliver(event)` and the stat accessor are each the only
   door. This keeps replays exact and keeps counters honest.
3. **Compose by explicit wiring, not by globals.** No autoload, no event bus, no container. The builder connects typed signals by hand, and a
   test fails on any signal with no listener.
4. **Rebuild, never reset.** Retry destroys the battle and builds a new one. No system has a reset function.
5. **Data decides values, code decides rules.** No gameplay number lives in code. Every value has an owning GDD and a rationale in the catalogue.
6. **Fail loud and stop.** Bad data, a broken scene or a contract breach latches Fatal. No silent defaults. A named gap in engine knowledge
   (`NOT SOURCEABLE`) blocks a story until an ADR or a phone run settles it.
7. **Thumb first.** Input is one resolver with one priority table. A drag that fires the wrong action is worse than a miss.

---

## Open Questions

Warnings M1 to M11 come from `design/gdd/gdd-cross-review-2026-11-02j.md`. They are tracked there. This table says where each one gets settled.

| ID | Summary | Priority | Resolution path |
|---|---|---|---|
| M1 | Nothing handles `lifecycle_changed` "quit requested" and "resized"; the provisional HUD record has no writer | High | ADR-0003 and ADR-0002; then a Flow GDD fix routing both through Rule 17 |
| M2 | A broken stage scene cannot Fatal "during `build`"; the wrapper loads `scene_ref` after `build` returns; who writes the Fatal record before views connect is unstated | High | ADR-0003 |
| M3 | `chip_state()` during `upgrade` (current or next level) is undefined | Medium | Tower stories; HUD story |
| M4 | Interface names and signatures differ between GDDs (`lifecycle_changed(state)`, `start_next_wave()`, `slot_tapped(slot_index)`, `chip_state()` fields, `bursts_started`, owner column) | Medium | ADR-0004 fixes canonical names; GDD fixes tracked in the review report |
| M5 | HUD Rule 10 states the pin cancel more loosely than Hero Rule 14 | Low | HUD story: use "within 48 at release, or never passed 64" |
| M6 | The Paused resume tap has no input route | High | ADR-0007 (overlay is a Control before the adapter) |
| M7 | Stale criteria and questions across GDDs (expired chip tap, wrong-disc question, snapshot question, hero share, ADR names) | Medium | Stories; snapshot question goes to ADR-0008 |
| M8 | "First run (challenge)" cannot order attempts across launches (`attempt_seq` resets) | Low | HUD debug-log story: say file order is the timeline, or add a persistent `tester_seq` |
| M9 | `call_prompt_done` lasts one launch | Low | Design call; the app root holds it for one launch |
| M10 | The Call prompt may teach a free move | Low | Design call (Hero "Always-call, humans" gate) |
| M11 | A hero standing still in Build may read as a failed pin | Low | Playtest risk, not an architecture item |
| A1 | Does the technical director accept cutting ProjectileSpawner and the tick order? | High | ADR-0005 |
| A2 | Does the technical director accept the composition root as a plain builder, and the HeroSim/HeroInput and TowerSim/TowerInput splits? | High | ADR-0003, ADR-0006 |
| A3 | Does the technical director accept path and slots moving from the scene to the Stage record? | Medium | ADR-0001, ADR-0005 |
| A4 | Stretch mode and aspect are unset in `project.godot`; 4.7 new-project defaults may not apply to this file | High | ADR-0007 |
| A5 | Scene checks run on the project, not on an export (the test runner cannot run on an exported build); is the manual export check enough? | Medium | ADR-0001 |
| A6 | Tablet `drag_slop` is 22 dp wide at 800 dp; does it need a scale cap? | Low | ADR-0002 |
| A7 | Safe-area and notch APIs, touch event classes and lifecycle notifications are absent from `docs/engine-reference/godot/`. Extend the reference or verify against live 4.7 docs | High | Before ADR-0002, ADR-0003 and ADR-0007 are accepted |
| A8 | Renderer: `project.godot` uses Mobile; the reference calls Forward+ desktop-focused and lists Compatibility as the widest. Confirm Mobile on the lowest target Android | Medium | ADR-0007; Vertical Slice device test |
| A9 | gdUnit4 is not installed; the framework runs on 4.7.2 per the reference | Medium | `/test-setup`, ADR-0008 |
