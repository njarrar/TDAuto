# TowerRiot: Master Architecture

## Document Status
- Version: 1
- Last Updated: 2026-11-03
- Engine: Godot 4.7.2 (GDScript, Mobile renderer, Godot Physics 2D). Pinned in `docs/engine-reference/godot/VERSION.md`.
- GDDs Covered (8 MVP systems): `data-config-pipeline`, `input-gesture-resolver`, `game-state-stage-flow`, `combat-damage`, `enemy-wave`, `tower-system`, `hero-system`, `battle-hud`. Context only: `game-concept`, `systems-index`.
- Vertical Slice and Alpha systems (14 of 22) have no GDD yet. They appear in the layer map as reserved slots with the seams MVP code must leave for them. This document is revised when those GDDs exist.
- ADRs Referenced: none exist yet. 15 are proposed (ADR-0001 to ADR-0015, numbers provisional until `/architecture-decision` assigns them). Every contract below that a GDD defers to an ADR is marked **ADR-pending**: it is a working default, not a decision.
- Technical Requirements: 120, all registered in `docs/architecture/tr-registry.yaml` (TR-data, TR-input, TR-state, TR-combat, TR-enemy, TR-tower, TR-hero, TR-hud). Coverage by ADRs: 0 of 120.
- TD-ARCHITECTURE: pending
- LP-FEASIBILITY: pending

## Engine Knowledge Gap Summary

The model's training covers Godot up to about 4.3. Versions 4.5, 4.6 and 4.7 are post-cutoff. The installed editor matches the pin (4.7.2).

| Domain | Risk for this project | Why | What it touches |
|---|---|---|---|
| Input (touch, mouse emulation) | **HIGH** | 4.7 mouse and keyboard no longer report device `0`. 4.6 split touch focus from keyboard focus. `modules/input.md` has no touch coverage, so every touch API claim in the GDDs is unverified. | Input adapter, resolver, HUD Controls, all hit targets |
| UI and display (stretch, safe area) | **HIGH** | 4.7 changed stretch defaults for new projects (`canvas_items` / `expand`). `project.godot` sets none, so the project inherits whatever the editor wrote. The 540x960 field space, layout rules L3 and L5 to L7 and the HUD layout all depend on it. | Display setup, every field-unit conversion, HUD layout |
| GDScript language | **HIGH** | 4.7: an override of a typed method inherits the return type and needs an explicit `return`. Packed array element writes skip the property setter. 4.5 added `@abstract` and variadic `...args`. Lambdas capture locals by value. | Every `.gd` file; base classes; signal handlers |
| Rendering (2D, Mobile renderer) | **MEDIUM** | 4.7: `CanvasItem` lines lose their antialiasing feather and look thinner. The Mobile renderer reference is desktop-leaning. The 60 draw-call budget is a proposal, not measured. | Field views, HUD `_draw`, path polygon |
| Resources and file access | **MEDIUM** | `duplicate()` on nested resources is deprecated for `duplicate_deep()` (4.5). `FileAccess.store_*` returns `bool` (4.4). | Catalogue snapshot test, run log, save/load (VS) |
| App lifecycle (pause, focus, background) | **HIGH, unreferenced** | The GDDs name `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_APPLICATION_PAUSED` and `NOTIFICATION_WM_WINDOW_FOCUS_OUT`. None is in the pinned reference. | Pause rule (TR-state-010), held-press clearing |
| Audio | **MEDIUM** (Alpha) | 4.7 `area_mask` default on `AudioStreamPlayer2D` changed to `0`. | Audio system, not before Alpha |
| Physics | **LOW** | The simulation uses no physics bodies or areas (Flow Rule 4). The 4.7 physics changes are all Jolt 3D. | None at MVP |
| Animation, Navigation, Networking | **N/A** | No skeletal animation, no pathfinding (the hero pins), no networking. | None |

Rule for this document: any engine behaviour that sits in a HIGH row is written as **NEEDS VERIFICATION** until an ADR author has checked it against the live 4.7 documentation or a device.

## System Layer Map

### Layers

```
┌────────────────────────────────────────────────────────────────────────────┐
│ COMPOSITION ROOT (exempt from the downward rule; nothing may depend on it) │
│   App Root (main scene)      Battle Builder (plain function)               │
├────────────────────────────────────────────────────────────────────────────┤
│ PRESENTATION   Battle HUD & Build UI · HeroInput · TowerInput · field      │
│                views · Visual Feedback (VS) · Menu (VS) · Onboarding (VS) · │
│                Audio (Alpha) · Settings & Accessibility (Alpha)            │
├────────────────────────────────────────────────────────────────────────────┤
│ FEATURE        Enemy & Wave · Tower (TowerSim + gold) · Hero (HeroSim +    │
│                Burst) · Stage Progression (VS) · Skill Points (VS) ·       │
│                Skill Tree (VS) · Hero Weapons (VS) · Synergies (VS/Alpha)  │
├────────────────────────────────────────────────────────────────────────────┤
│ CORE           Game State & Stage Flow (pure Flow machine, tick clock) ·   │
│                Combat & Damage · Stat & Modifier Resolution (VS)           │
├────────────────────────────────────────────────────────────────────────────┤
│ FOUNDATION     Data & Config (catalogue, validator, stat accessor) ·       │
│                Input & Gesture Resolver (+ adapter) · Fatal path ·         │
│                Mobile Platform & Performance (VS) · Save/Load (VS)         │
├────────────────────────────────────────────────────────────────────────────┤
│ PLATFORM       Godot 4.7.2 · Mobile renderer · DisplayServer · OS touch    │
└────────────────────────────────────────────────────────────────────────────┘
```

### Dependency rules

1. A module may depend on its own layer and on layers below it. It may not depend on a layer above it.
2. **Composition Root is the one exemption.** App Root and Battle Builder reference every layer because wiring is their only job. No module references them. Anything a module needs from the root arrives as an injected value, `Callable` or signal.
3. Presentation reads the simulation only through read-only queries and view signals. The simulation never references Presentation, and gives identical results with or without it (TR-hud-004, TR-combat-010, TR-hero-008).
4. Inside Feature, Enemy & Wave, Tower and Hero do not reference each other. They meet only in the builder, through signals and injected callables.
5. Combat (Core) cannot name the enemy class (Feature) without an upward dependency. Combat therefore defines the shape it needs (`spawn_id`, `position`, `removed`, plus the Health and Status it attaches) and Enemy & Wave supplies an object of that shape. **ADR-pending** (ADR-0011).

### System-to-layer table

| # | System | Index tier | Layer here | Notes |
|---|---|---|---|---|
| 1 | Data & Config Pipeline | MVP | Foundation | Catalogue, validator and stat accessor |
| 2 | Input & Gesture Resolver | MVP | Foundation | Pure resolver plus one engine-facing adapter node |
| 3 | Game State & Stage Flow | MVP | Core (Flow) and Composition (App Root, Builder) | The systems index calls this one Core. The GDD gives it two jobs, so it splits |
| 4 | Combat & Damage | MVP | Core | Three pieces: DamageEvent, Health, Status |
| 5 | Enemy & Wave | MVP | Feature | Roster owner; path and slots live on the Stage record |
| 6 | Tower System | MVP | Feature (TowerSim) and Presentation (TowerInput) | Gold economy is inside TowerSim |
| 7 | Hero System | MVP | Feature (HeroSim, Burst) and Presentation (HeroInput) | Hero never references Burst; the HUD reads cooldown |
| 8 | Battle HUD & Build UI | MVP | Presentation | HudLogic, HudTopBand, HudField |
| 9 | Stat & Modifier Resolution | VS | Core | Drops in behind the Foundation stat accessor |
| 10 | Skill Point Economy | VS | Feature | Reserved |
| 11 | Skill Tree System | VS | Feature | Reserved |
| 12 | Hero Weapons | VS | Feature | Reserved |
| 13 | Stage Progression & Stars | VS | Feature | Owns end-of-stage report and stage preview |
| 14 | Save/Load | VS | Foundation | The systems index lists it as a Polish layer system. This document uses the layer definition in `/create-architecture`, which puts save/load in Foundation. Progression systems own their schemas; Save injects state at boot |
| 15 | Menu & Screen Flow | VS | Presentation | Reserved |
| 16 | Mobile Platform & Performance | VS | Foundation | Safe areas, export, pooling. **Needs a GDD before the first phone build** |
| 17 | Onboarding Prompts | VS | Presentation | Reserved |
| 18 | Cross-Tree Synergy Hook | VS | Feature | Reserved |
| 19 | Visual Feedback & VFX | VS | Presentation | Reserved |
| 20 | Audio | Alpha | Presentation | Reserved |
| 21 | Settings & Accessibility | Alpha | Presentation | Owns Reduce Motion. Location of the setting is an open question (QQ-09) |
| 22 | Cross-Tree Synergies (full) | Alpha | Feature | Reserved |

Note on requirement tags: the `Layer` column in `requirements-traceability.md` tags each *requirement* by the kind of work it asks for. It does not override the system layer above. Enemy & Wave, Tower and Hero requirements are tagged Core there because they run inside the tick; their module layer is Feature, as in the systems index.

### Seams MVP code must leave for later tiers

| Later system | Seam MVP code must keep |
|---|---|
| Stat & Modifier Resolution (VS) | Every modifiable value is read through the one stat accessor at use time, never cached (TR-data-008). The resolver replaces the accessor's internals with no call-site change. Modifier source tags are reserved now. |
| Save/Load (VS) | Progression systems expose `to_dict()` / `from_dict()` with a version field and never call Save. MVP has nothing to save, so no save code is written, but no MVP system may hold progression state in a global. |
| Stage Progression (VS) | Flow keeps its result (outcome, last wave started, lives left, Combat per-source damage) readable after the outcome (TR-state-006, TR-combat-005). |
| Skill Tree / Hero Weapons (VS) | Hero and Tower read stats through the accessor with a read context holding `def_id`, so a tree node changes a stat without touching Hero or Tower code. |
| Settings (Alpha) | Reduce Motion is read by views from one place. Location is **ADR-pending** (QQ-09). |

## Module Ownership

Naming follows `project.yaml`: classes PascalCase, files snake_case, signals past tense. Signal names that break the past-tense rule are listed in QQ-07.

Code root is `src/` (Godot). Proposed folders, one per layer: `src/foundation/`, `src/core/`, `src/feature/`, `src/presentation/`, `src/root/`. Tests mirror them under `tests/unit/` and `tests/integration/`.

### Foundation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **Catalogue** (Data & Config) | The Ready catalogue: typed read-only records (Tower, Enemy, Wave, Stage, Hero, Burst, Input). The manifest. Load state (Unloaded, Loading, Ready, Failed). | `load(manifest) -> LoadResult`; typed record lookup by ID; `is_tower(id)`, `level_count(def_id)` (non-fatal) | Data files via manifest | `Resource` or JSON, `ResourceLoader` / `FileAccess` (MEDIUM; format is ADR-0002). `duplicate_deep()` for snapshot tests (4.5, MEDIUM) |
| **Validator** (inside Data & Config) | Error list `{code, source, record_id, field}`. Tiered checks. | `validate(records) -> Array[ValidationError]` | Catalogue records | None (plain GDScript) |
| **StatAccessor** (Data & Config) | Stat-key vocabulary and int/float type per key. Nothing else; no stored values. | `stat(read_context, key) -> int or float`; calls the injected failure handler on a bad call | Catalogue; later Stat & Modifier | None |
| **InputResolver** | Hit-target registry, the four-state machine, the FIFO re-entrancy queue, the frozen winners of the current press. No clock, no scene. | `press`, `move`, `release`, `cancel_pointer`, `cancel`; `register`, `unregister`, `set_centre`, `set_enabled`; signals `pressed`, `tap`, `ground_tap`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `idle` | Input record (slops), injected at `create()` | None |
| **InputAdapter** (the only engine-facing input code) | Translation of engine events to the five resolver calls; edge and safe-area rejection; touch/mouse de-duplication; lifecycle `cancel()` calls | Forwards one lifecycle signal (pause) for Flow | Godot input events, `DisplayServer`, viewport | `InputEventScreenTouch`, `InputEventScreenDrag` and the `canceled` flag (**HIGH, NEEDS VERIFICATION**); `_unhandled_input` vs `Control` ordering (**HIGH**); `Node.PROCESS_MODE_ALWAYS` (LOW); `DisplayServer.get_display_safe_area()` (**HIGH**); `Viewport.size_changed` (LOW); app lifecycle notifications (**HIGH**); mouse device ID change (4.7, **HIGH**) |
| **FatalPath** | The single idempotent fatal handler: first cause kept, latch, halt. The catalogue-free fatal screen scene. | `fatal(cause)` injected as a `Callable` everywhere; `is_fatal()` | Nothing (must not depend on the catalogue) | `push_error` (LOW). `assert` is never used for release-relevant checks (stripped in exports) |
| *Mobile Platform (VS)* | Safe-area mapping, export presets, effect pooling, particle caps | Reserved | | `DisplayServer` (HIGH) |
| *Save/Load (VS)* | Save file, version field, migration | Reserved | | `FileAccess` (MEDIUM) |

### Core

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **Flow** (Game State, pure object) | Stage state machine (Build, Wave, Intermission, Paused, Won, Lost). Lives. `intermission_left` as integer ticks. The stage result. | `in_build()`, `halted()`, `intermission_left`, result; commands `start_wave()`, `call_early()`, `pause()`, `resume()`, `retry_requested`; signals `lives_changed`, `phase`, `wave_called_early` | Enemy & Wave signals (`wave_cleared`, `waves_complete`, `enemy_leaked`); lifecycle signal from the adapter | None |
| **Clock** (tick scheduler, in the battle wrapper) | `battle.tick(dt)` call rate, accumulator, catch-up clamp. The only place real time becomes simulation time. | `tick(dt)` entry on the Battle | Frame delta | `Node._process` in the wrapper only (LOW); decision on `_process` vs `_physics_process` is ADR-0004 |
| **Combat** | `DamageEvent` value, one Health and one Status per enemy, per-source damage counters. | `deliver(event) -> float`; `apply_slow`; `speed_factor(enemy)`; `tick_status(roster)`; `first_in`, `nearest_in`, `all_in_radius`; `dealt_by_id`, `dealt_by_kind`, `dealt_total`, `hero_share`; `is_dead`, `hp_left`; `report_attack`; `to_ticks` | Values passed in by callers; `dt` injected at build | None (pure) |
| *Stat & Modifier (VS)* | Modifier stack, fixed evaluation order | Behind `StatAccessor` | Catalogue, tree nodes | None |

### Feature

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **EnemyWave** | Roster (sole owner of enemies), wave state machine, cached positions along the path polyline, `spawn_id` counter | `roster()`, `targets()` (both in `spawn_id` order, valid for the slot only); `advance(tick)`, `reap()`, `start_next_wave()`, add-enemy step; signals `enemy_leaked(lives_cost)`, `enemy_killed(bounty)`, `wave_cleared(intermission_duration)`, `waves_complete` | Stage and Wave records (direct), stats via accessor, Combat attach call, injected `halted()` and error sink | None in the sim. Views use `CanvasItem._draw` (see Presentation) |
| **TowerSim** | Gold (non-negative int), slots, towers, per-tower `cooldown_left` (ticks) | `build(slot_index, tower_id) -> Result`, `upgrade(slot_index) -> Result`, `tick()`, `slot_state()`, `gold`; signals `gold_changed`, `tower_built`, `tower_upgraded` | Stage record, accessor, `enemy_killed` and `wave_called_early` (forwarded by Flow), Combat helpers, injected `halted()` | None |
| **HeroSim** | Hero position, pin target, pin state, burst state, cooldown, telegraph, run counters | `pin(pos) -> Result`, `burst(pos) -> Result`, `tick()`, read-only queries (`position`, `pin_target`, `pin_state`, `burst_state`, `cooldown_left`), counters; signals `hero_pinned`, `burst_started` | Stage record (`hero_start`, `pin_rect`, `pin_exclusion`), accessor, Combat, `targets()`, injected `halted()` and `in_build()` | None |
| **PinGeometry** | Pure clamp and validity maths in float scalars | `is_valid(pos)`, `clamp(pos)` | Pin rect and exclusion segments | None (avoids `Vector2` methods on purpose, see QQ-05) |
| *Stage Progression, Skill Points, Skill Tree, Hero Weapons, Synergies (VS/Alpha)* | Reserved | | | |

### Presentation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **HudLogic** | HUD presentation state (button arm model, arc state, snapshot). No gameplay state. | `advance(ms)`, view-model reads | Flow, TowerSim, HeroSim, EnemyWave, Combat (read-only), accessor for costs | None |
| **HudTopBand** | Display-only `Control`s that ignore input | None | HudLogic | `Control`, `mouse_filter` (HIGH, 4.6 dual focus) |
| **HudField** | One `_draw` for field art; hit targets are resolver discs | None | HudLogic, resolver registry | `CanvasItem._draw` (MEDIUM, 4.7 line feather) |
| **ResultScreen, PausedScreen** | Full-screen modal `Control`s | Retry, Resume requests | Result snapshot | `Control` input consumption before the adapter (**HIGH, NEEDS VERIFICATION**) |
| **HeroInput** | Aim state machine (Idle, Cancelling, Live), aim-point re-clamp, cancel hysteresis | `update()`, `cooldown_digit()` | Resolver signals, HeroSim queries, `burst_button_centre()` from the HUD | None |
| **TowerInput** | Slot and chip discs, `ChipWindow` | `slot_tapped`, `tower_inspected` | Resolver, TowerSim, Flow `phase` | None |
| **ChipWindow** | Real-time upgrade-chip timing | `advance(ms)` | Fed by the wrapper each frame | None |
| **Field views** (enemy, tower, combat, path) | Pools, draw order, flash markers (16 max), enemy view pool (at least 48) | None | `roster()`, `slot_state()`, Combat view signals | `CanvasItem._draw`, `draw_polyline` or a baked polygon (MEDIUM, **NEEDS VERIFICATION** for 90 degree corners at width 72) |
| **RunLog / GestureLog** (dev only) | JSONL records, gesture records | Injectable sink | Signals only | `FileAccess` append (MEDIUM; check the `bool` return) |

### Composition Root

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **AppRoot** (main scene, no autoload) | The Ready catalogue for the session. The fatal screen. The retry latch. Reduce Motion location (QQ-09). | Starts the catalogue load; builds and frees battles | Catalogue, FatalPath | `Node`, `PackedScene`, `Object.free()` vs `queue_free()` timing on retry (**MEDIUM, NEEDS VERIFICATION**), `weakref()` (LOW) |
| **Builder** (`build(catalogue, stage_id, seed, fatal_handler)`) | Nothing persistent. Constructs one `Battle` and makes every connection. | Returns a `Battle` | Every sim module | `Signal.connect(Callable)` (LOW). No `CONNECT_DEFERRED` on gameplay signals (TR-enemy-004) |
| **BattleWrapper** (scene) | Tick loop, input adapter, views, the HUD. Absent headless. | None | Battle, adapter | `Node._process`, `PROCESS_MODE_ALWAYS` |

### Dependency diagram (MVP)

```
                          ┌──────────── AppRoot ────────────┐
                          │ owns Catalogue, FatalPath       │
                          └──────────────┬──────────────────┘
                                         │ build(catalogue, stage, seed, fatal)
                                         ▼
 ┌────────────────────────────── Battle (plain object) ───────────────────────────┐
 │                                                                                │
 │   Flow ◄──signals── EnemyWave ──attach/targets──► Combat ◄──deliver── TowerSim │
 │    │  ▲                │  ▲                          ▲  ▲                │     │
 │    │  └─ phase,lives   │  └── roster()/targets() ────┘  └── deliver ── HeroSim  │
 │    │                   │                                                  ▲     │
 │    └─ halted(), in_build() injected into EnemyWave, TowerSim, HeroSim ────┘     │
 │                                                                                │
 │            every stat read ──► StatAccessor ──► Catalogue (read-only)           │
 └────────────────────────────────────────────────────────────────────────────────┘
        ▲ commands between ticks                       │ view signals, read-only queries
        │ (pin, burst, build, upgrade, call, start)    ▼
 ┌──────┴──────────── BattleWrapper (absent headless) ───────────────────────────┐
 │ InputAdapter ─► InputResolver ─► HeroInput / TowerInput / HudLogic            │
 │ Clock (accumulator, clamp) ─► battle.tick(dt)        Views: Hud, Field, Combat│
 └────────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

Everything runs on the main thread. No data flow crosses a thread boundary, and none may be added without an ADR (the sim is deterministic and single-threaded by design, TR-state-003, TR-state-005).

Every flow below is a **working default** drawn from the GDDs. Items marked ADR-pending are ratified by the named ADR.

### 1. Frame update path

```
Engine delivers input events (before this frame's _process; NEEDS VERIFICATION, ADR-0004)
  InputAdapter ──► InputResolver ──► signals ──► HeroInput / TowerInput / HudLogic
                                                    │ commands: pin, burst, build, upgrade,
                                                    │ start_wave, call_early  (run NOW, between ticks)
BattleWrapper._process(delta):
  1. Advance real-time models:  HudLogic.advance(ms), ChipWindow.advance(ms), HeroInput.update()
  2. Clock: accumulator += delta; ticks_owed = min(floor(acc / dt), clamp)
  3. for each owed tick:  if battle is halted: break;  battle.tick(dt)
  4. Refresh views from read-only queries (roster, slot_state, hero queries, HUD view-models)
```

| Data | Producer | Consumer | Kind |
|---|---|---|---|
| Touch/mouse events | Godot | InputAdapter | Engine callback |
| Five resolver calls | InputAdapter | InputResolver | Synchronous call |
| Gesture signals | InputResolver | HeroInput, TowerInput, HudLogic | Signal (synchronous) |
| Commands | HeroInput, TowerInput, HudLogic, bots | HeroSim, TowerSim, Flow | Synchronous call, **only between ticks**, returns a result enum |
| `tick(dt)` | Clock | Battle | Synchronous call |
| View reads | Views | Sim modules | Read-only query |

Rule: commands run from the input call stack, before the frame's ticks, so the bonus the HUD shows equals the bonus paid (TR-hud-005). Whether input is delivered before `_process` on 4.7 is **NEEDS VERIFICATION** (ADR-0004).

### 2. Simulation tick path

`battle.tick(dt)` runs these steps in this order, every tick, Intermission included (Build runs no ticks). The order is stated once, here and in ADR-0004; the four GDDs that restate it (Game State Rule 5, Combat Rule 11, Enemy & Wave Rule 12, Tower Rule 9) cite it.

```
1. Flow.tick               (intermission countdown, wave start/clear checks)
2. EnemyWave.advance       (spawn from absolute schedule, move, leak)     ── leaks resolve BEFORE fire
3. Combat.tick_status      (slow countdown over the roster)
4. TowerSim.tick           (by ascending slot index: cooldown, target, report_attack, deliver)
5. HeroSim.tick            (walk, attack, cooldown, telegraph, release; burst after hero)
6. EnemyWave.reap          (remove corpses, emit enemy_killed(bounty) once each)
```

After any step that can commit an outcome (leak, kill, fatal), later steps check `halted()` and return at once (TR-state-007, TR-enemy-005, TR-tower-006).

### 3. Event and signal path

| Signal | Emitter | Listeners | Rule |
|---|---|---|---|
| `enemy_leaked(lives_cost)` | EnemyWave | Flow | Synchronous, state committed before emit, spawn_id order |
| `enemy_killed(bounty)` | EnemyWave | TowerSim (gold) | Same |
| `wave_cleared(intermission_duration)` | EnemyWave | Flow | Same; leaks come before the clear |
| `waves_complete` | EnemyWave | Flow | Same |
| `lives_changed`, `phase`, `wave_called_early(seconds_left)` | Flow | HUD, TowerSim (`wave_called_early`), views | `phase` and `lives_changed` join the view allowlist |
| `gold_changed`, `tower_built`, `tower_upgraded` | TowerSim | HUD, views | Commit first, `gold_changed` then the tower signal; a refusal emits nothing |
| `hero_pinned`, `burst_started` | HeroSim | Views, HUD | After state set; handlers never issue commands |
| `attack_fired`, `damage_applied` | Combat | Combat view, audio (Alpha) | View-only; listeners never call `deliver` |
| Gesture signals | InputResolver | HeroInput, TowerInput, HudLogic | Re-entrant calls queue FIFO and drain in the outermost call |

Rules for all of them (ADR-0009):
1. **Commit, then emit.** State is final before the first listener runs.
2. **Gameplay does not depend on listeners.** A battle with every view listener removed produces identical state (TR-tower-012, TR-hud-004).
3. **Wiring signals** (the ones in the first six rows that the sim itself consumes) are connected only in the Builder, never deferred.
4. **View allowlist.** A test fails if any battle signal has no listener, except signals on a named allowlist (TR-state-013).
5. Signals use typed parameters. The type of `tower_id` is undecided (QQ-04).

### 4. Initialisation order

```
Engine starts main scene ──► AppRoot._ready
  1. FatalPath ready (catalogue-free fatal scene is loadable)
  2. Catalogue.load(manifest)         Unloaded ─► Loading ─► Ready | Failed
       Failed ─► fatal screen (no fallbacks, no save access)
  3. (VS) Save/Load boot: inject loaded progression into progression systems
  4. AppRoot holds Ready catalogue, picks stage_id and seed
  5. Builder.build(catalogue, stage_id, seed, fatal_handler)
       a. Validate stage inputs; construct InputResolver via create() (null on bad slops: fatal)
       b. Construct Flow, Combat, EnemyWave, TowerSim, HeroSim
       c. Make every signal connection and inject halted(), in_build(), error sink
       d. Return Battle (headless-safe: no node touched)
  6. BattleWrapper adds InputAdapter, Clock, HUD and field views around the Battle
  7. Flow enters Build
```

Dependency note: the stat accessor cannot be used before step 2 finishes. The resolver reads its slops directly from the Input record, not through the accessor (TR-input-012).

### 5. Retry and teardown path

```
Result screen "Retry" pressed
  ─► sets idempotent retry latch on AppRoot (does NOT free the caller)
AppRoot next frame:
  1. If Fatal: show fatal screen, stop
  2. Stop Clock;  InputResolver.cancel()
  3. Free the Battle, the wrapper, the adapter, the resolver and all views (no old reference may survive;
     a weakref to the old Battle must read null: TR-state-009, TR-enemy-008, TR-tower-013)
  4. Builder.build(...) again with the SAME catalogue (it is held by AppRoot)
```
Retry resets nothing in place. It rebuilds. `free()` vs `queue_free()` timing is **NEEDS VERIFICATION** (ADR-0001).

### 6. Pause and focus path

```
App loses focus / backgrounds  (notification names NEEDS VERIFICATION, ADR-0006)
  InputAdapter ─► resolver.cancel()  and forwards one lifecycle signal
  Flow: remember phase, enter Paused: Clock stops, accumulator zeroed, input cancelled
  A finger held across the pause stays dead until lifted; the resume tap reaches nothing beneath
  Resume: Flow restores the remembered phase;  walk and telegraph resume exactly (TR-hero-013)
```
Real-time models (button arming, chip window) freeze while Paused (TR-hud-007).

### 7. Fatal path

```
Any of: catalogue load failure · bad accessor call · broken stage scene · bad stage input
  ─► fatal(cause)   (injected Callable; idempotent; keeps the FIRST cause)
       latches on Battle and AppRoot, halts the current tick, discards a partial build
       shows a catalogue-free fatal screen, never opens saves
  Development builds name each error by file, record and field.
```
GDScript has no exceptions, so after `fatal` every caller checks `halted()` and returns (TR-state-011).

### 8. Save/load path (Vertical Slice, reserved)

Not built at MVP. The contract MVP code must respect: progression systems own their schema, expose `to_dict()` and `from_dict()` with a `version` field, and never call Save. Save owns the file and injects loaded state at boot (step 3 above). The serialised state will be skill points, tree nodes, weapons, stars and settings. No battle state is ever saved, because a battle is rebuilt from `(catalogue, stage_id, seed)`.

### 9. Dev telemetry path

Development builds only. A gesture-log harness listens to resolver signals; a run log appends JSON lines to `user://run_log.jsonl` through an injectable sink. A write failure is non-fatal and release builds never write (TR-hud-013, TR-input-015). Both listen only; neither can change a result.

## API Boundaries

Contracts are GDScript sketches. They fix names, direction and invariants, not final signatures. Each block names the ADR that ratifies it. Engine types used are flagged with the 4.7 check: `RefCounted`, `Callable`, `Signal`, `StringName`, `Resource`, `Node` (all stable since 4.0, no signature change in 4.5 to 4.7 per `breaking-changes.md`).

All simulation classes extend `RefCounted`, never `Node`. A freed `Node` cannot honour `removed`, and a `Node`'s built-in `position` would collide with Combat's cached one (TR-combat-002).

### B1. Stat accessor (ADR-0005, ADR-0002)

```gdscript
class_name StatAccessor extends RefCounted

## read_context: {def_id: StringName, level: int = 0, live_entity: Object = null}
## Returns the type declared for the key (int or float). Never cache the result,
## except max_hp when seeding Health.
func stat(read_context: ReadContext, key: StringName) -> Variant

## Non-fatal lookups. Call these before stat() when an ID or level is not already trusted.
func is_tower(id: StringName) -> bool
func level_count(def_id: StringName) -> int
```
Invariants: a bad call (unknown or inapplicable key, bad level, unresolved `def_id`) calls the injected failure handler. The check survives release builds, so it is not an `assert`. The return type is `Variant` because typed GDScript cannot express "number or nothing" (a 4.7 typed-return override also needs an explicit `return`). Callers pick the typed local.

### B2. Input resolver (ADR-0010, ADR-0006)

```gdscript
class_name InputResolver extends RefCounted

static func validate(slops: InputRecord) -> Array[String]       # empty = valid
static func create(slops: InputRecord) -> InputResolver         # null when invalid

# Driven only by the adapter (or tests). Positions are 540x960 field units.
func press(pointer: int, pos: Vector2) -> void
func move(pointer: int, pos: Vector2) -> void
func release(pointer: int, pos: Vector2) -> void
func cancel_pointer(pointer: int) -> void
func cancel() -> void

# Registry. Legal in any state, including inside handlers; effective at once.
func register(centre: Vector2, radius: float, accepts: int, priority: int, sink: Object) -> int  # id from 1, never reused
func unregister(id: int) -> void
func set_centre(id: int, centre: Vector2) -> void
func set_enabled(id: int, enabled: bool) -> void

signal pressed(best_tap: int, best_drag: int)   # both winners exposed: TR-hud-009
signal tap(id: int)
signal ground_tap(pos: Vector2)
signal drag_started(id: int, pos: Vector2)
signal drag_moved(id: int, pos: Vector2)        # one per input call, never per frame
signal drag_ended(id: int, pos: Vector2)
signal drag_cancelled(id: int)
signal idle()                                   # last signal of every exit to Idle
```
Invariants: single active pointer. Winners and their discs are frozen at press (tie-break: priority, then squared distance, then id). Gesture calls made inside a handler queue FIFO and drain synchronously in the outermost call. No clock, no scene tree, no engine events. Signal names that break the past-tense rule: QQ-07.

### B3. Input adapter (ADR-0006)

```gdscript
class_name InputAdapter extends Node        # process_mode = PROCESS_MODE_ALWAYS
signal lifecycle_paused()                   # one signal for Flow
# Contract: every forwarded press is followed by exactly one release, cancel_pointer or cancel()
# for that index, even when a Control with mouse_filter = STOP lies under the drag.
# Calls resolver.cancel() on pause, focus loss and viewport resize.
```
Everything in this block is **NEEDS VERIFICATION** against live 4.7 docs: event path (`_unhandled_input` vs `_input`), `InputEventScreenTouch.canceled`, emulation settings, pointer-index collision, `get_display_safe_area()` units. The adapter converts window pixels to field units, so stretch mode must keep field units equal to viewport units (no `Camera2D`, QQ-02).

### B4. Battle and Builder (ADR-0001, ADR-0004)

```gdscript
class_name Battle extends RefCounted
func tick(dt: float) -> void                # the ONLY way simulation time advances
func halted() -> bool
# Read-only members: flow, combat, enemy_wave, tower_sim, hero_sim

class_name BattleBuilder extends RefCounted
static func build(catalogue: Catalogue, stage_id: StringName, seed: int, fatal: Callable) -> Battle
```
Invariants: `build` touches no node, so bots and tests call it headless. It makes every connection in one function. It is not called from inside a signal. Gameplay classes never read `Engine`, `Time`, `OS`, a timer or `await`.

### B5. Flow (ADR-0004, ADR-0009)

```gdscript
class_name Flow extends RefCounted
enum Phase { BUILD, WAVE, INTERMISSION, PAUSED, WON, LOST }
func in_build() -> bool
func halted() -> bool
func tick() -> void
func start_wave() -> int                    # result enum, between ticks
func call_early() -> int
func pause() -> void
func resume() -> void
var intermission_left: int                  # integer ticks, never float subtraction
signal phase(value: Phase)                  # breaks the past-tense rule: QQ-07
signal lives_changed(lives: int)
signal wave_called_early(seconds_left: float)
```
Outcome commit order: set state, stop the clock, `input.cancel()`, then emit.

### B6. Combat (ADR-0012, ADR-0011)

```gdscript
class_name Combat extends RefCounted
enum SourceKind { TOWER, HERO, BURST }

class DamageEvent:
    var target: Object
    var amount: float
    var source_kind: SourceKind
    var source_id: StringName

func deliver(event: DamageEvent) -> float                 # applies min(amount, hp); only inside a tick
func apply_slow(target: Object, factor: float, duration_ticks: int) -> void
func speed_factor(target: Object) -> float
func tick_status(roster: Array) -> void
func first_in(list: Array, centre: Vector2, max_range: float) -> Object      # lowest spawn_id on ties
func nearest_in(list: Array, centre: Vector2, max_range: float) -> Object
func all_in_radius(list: Array, centre: Vector2, max_range: float) -> Array
func is_dead(target: Object) -> bool
func hp_left(target: Object) -> float
func report_attack(source_kind: SourceKind, source_id: StringName, pos: Vector2) -> void
func dealt_by_id(id: StringName) -> float
func hero_share() -> float
signal attack_fired(kind: SourceKind, source_id: StringName, from_pos: Vector2, to_pos: Vector2)
signal damage_applied(event: DamageEvent, applied: float, pos: Vector2, killed: bool, spawn_id: int)
```
Invariants: every HP change goes through `deliver`. Guards run in a fixed order (removed, amount, dead) and report named `push_error` codes. The parameter is `max_range` because `range` is a GDScript global. Combat reads no catalogue data. Helpers never mutate the list and skip the dead. View signals carry copied positions, and listeners never call `deliver`. The signal parameter lists above are sketches; ADR-0009 fixes them.

### B7. Enemy and Wave (ADR-0011)

```gdscript
class_name EnemyWave extends RefCounted
func advance(tick: int) -> void
func reap() -> void
func start_next_wave() -> void              # parameterless; commits at wave_tick 0
func roster() -> Array                      # spawn_id order; caller must not hold it past its slot
func targets() -> Array                     # targetable only: centre inside the 540x960 field
signal enemy_leaked(lives_cost: int)
signal enemy_killed(bounty: int)
signal wave_cleared(intermission_duration: float)
signal waves_complete()
```
Enemy object shape (ADR-pending): `spawn_id: int` (battle-wide, never reused), `def_id: StringName`, `distance: float`, `position: Vector2` (cached once per tick), `removed: bool`, plus the Health and Status that Combat attaches at spawn. The enemy stays a valid reference after removal.

### B8. TowerSim and HeroSim commands (ADR-0013)

```gdscript
class_name TowerSim extends RefCounted
enum BuildResult { OK, HALTED, BAD_SLOT, BAD_TOWER, SLOT_OCCUPIED, NO_GOLD }
enum UpgradeResult { OK, HALTED, BAD_SLOT, NO_TOWER, MAX_LEVEL, NO_GOLD }
func build(slot_index: int, tower_id: StringName) -> BuildResult
func upgrade(slot_index: int) -> UpgradeResult
signal gold_changed(current: int)
signal tower_built(slot_index: int, tower_id: StringName)   # tower_id type: QQ-04
signal tower_upgraded(slot_index: int, level: int)

class_name HeroSim extends RefCounted
enum PinResult { HALTED, BAD_POSITION, OUT_OF_BOUNDS, BUTTON_ZONE, OK }
enum BurstResult { HALTED, BUILD_PHASE, NOT_PINNED, NOT_READY, BAD_POSITION, OFF_FIELD, OUT_OF_REACH, OK }
func pin(pos: Vector2) -> PinResult
func burst(pos: Vector2) -> BurstResult
signal hero_pinned(pos: Vector2)
signal burst_started(pos: Vector2)
```
Invariants: commands run only between ticks. State is checked before geometry. A refusal mutates and emits nothing. All stats a command needs are read before any mutation, so a bad read halts with nothing half done. Check order is fixed and is the order of the enum.

### B9. Injected callables (ADR-0001, ADR-0003)

| Callable | Injected into | Meaning |
|---|---|---|
| `halted() -> bool` | EnemyWave, TowerSim, HeroSim, HudLogic | True once Fatal or an outcome is committed. Checked after every accessor read and every signal. |
| `in_build() -> bool` | HeroSim, HeroInput, HudLogic | True while Flow is in Build. |
| `fatal(cause: String) -> void` | Builder, accessor, all sims | The one idempotent handler. |
| `dev_error(msg: String) -> void` | EnemyWave, others | Development-error sink that survives release builds. Tests replace it. |
| `to_ticks(seconds: float) -> int` | Combat, EnemyWave, TowerSim, HeroSim, Flow | Rounds half away from zero; `dt` fixed at build. |

### B10. HUD read surface (ADR-0009, ADR-0013)

The HUD reads, never writes: `Flow.phase`, `lives`, `intermission_left`; `TowerSim.gold`, `slot_state()`; `HeroSim` queries and `cooldown_left`; `EnemyWave.wave_index()`, `got_through_by_type()`; `TowerSim.chip_state()`; `Combat.hero_share()` for the end-of-stage log. New view-only reads the GDDs request and that do not exist yet: `wave_index()`, `got_through_by_type()`, `chip_state()`, `tower_inspected`, the cooldown total. `burst_button_centre()` is owned by the HUD and read once by HeroInput at registration.

## ADR Audit

### ADR Quality Check

No ADRs exist (`docs/architecture/adr-*.md` matches nothing; `adr-dep-graph.sh` reports `ADRS: 0`). There is nothing to check for engine compatibility, version, post-cutoff flags, GDD linkage or conflict with the layers above. The first `/architecture-review` after the ADRs are written performs this check.

### Traceability Coverage Check

Technical Requirements Baseline: **120 requirements from 8 GDDs, 120 registered, 0 provisional** (TR registry read, 120 entries, all `active`). No GDD contributed zero requirements. The full per-requirement matrix is `docs/architecture/requirements-traceability.md`; the review that built it is `docs/architecture/architecture-review-2026-11-03.md`.

| Status | Count |
|---|---|
| Covered by an Accepted ADR | 0 |
| Covered by a Proposed ADR | 0 |
| Partial | 0 |
| **Gap** | **120** |

By GDD: data-config 15, input 16, game-state 14, combat 14, enemy-wave 15, tower 15, hero 15, battle-hud 16. By layer tag: 53 Foundation, 44 Core, 3 Feature, 20 Presentation. By engine risk: 14 HIGH, 31 MEDIUM, 75 LOW.

The per-ADR coverage in the next section assigns every one of the 120 requirements to exactly one proposed ADR, so no requirement is left without a planned decision.

## Required ADRs

Fifteen ADRs close all 120 gaps. Numbers are proposed, in dependency order. The review used labels P01 to P15; the column maps them. `/architecture-decision` assigns the final numbers.

| Proposed ID | Title | Layer | Depends on | Review label | TRs | Engine risk |
|---|---|---|---|---|---|---|
| ADR-0001 | App Lifecycle, Composition Root and Battle Builder | Foundation | none | P01 | 11 | MEDIUM |
| ADR-0002 | Catalogue Storage Format, Manifest and Validation | Foundation | none | P03 | 10 | HIGH |
| ADR-0003 | Fatal Error Path and Release-Safe Checks | Foundation | ADR-0001 | P06 | 4 | HIGH |
| ADR-0004 | Fixed-Tick Simulation Clock, Tick Order and Frame Order | Foundation | ADR-0001 | P02 | 16 | HIGH |
| ADR-0005 | Stat Accessor and Read-Context Contract | Foundation | ADR-0002, ADR-0003 | P04 | 6 | LOW |
| ADR-0006 | Input Adapter, Display Stretch and Platform Lifecycle | Foundation | ADR-0001, ADR-0004 | P05 | 11 | HIGH |
| ADR-0007 | Determinism, Seeded RNG and Float Policy | Foundation | ADR-0004 | P07 | 4 | MEDIUM |
| ADR-0008 | Headless Test Harness and gdUnit4 Configuration | Foundation | ADR-0001, ADR-0003 | P08 | 7 | MEDIUM |
| ADR-0009 | Battle Signal Contracts and View Allowlist | Core | ADR-0001, ADR-0004 | P10 | 10 | MEDIUM |
| ADR-0010 | Input Resolver Core and Signal Contract | Core | ADR-0006, ADR-0009 | P09 | 10 | MEDIUM |
| ADR-0011 | Enemy Entity Kind, Roster and Combat Attachment | Core | ADR-0001, ADR-0005 | P11 | 9 | MEDIUM |
| ADR-0012 | Combat Delivery and Targeting API | Core | ADR-0011 | P12 | 7 | LOW |
| ADR-0013 | Sim/Input Split and Command Result Codes | Core | ADR-0004, ADR-0010, ADR-0012 | P13 | 7 | LOW |
| ADR-0014 | Battle Field Rendering and Draw-Call Budget | Presentation | ADR-0011, ADR-0013 | P14 | 5 | MEDIUM |
| ADR-0015 | Dev Telemetry: Gesture Log and Run Log | Feature | ADR-0010, ADR-0013 | P15 | 3 | LOW |

### What each ADR decides and which requirements it covers

**ADR-0001 App Lifecycle, Composition Root and Battle Builder** (Foundation). Decides: no autoloads, app root, scene-free builder, injection, retry teardown and weakref proof.
Covers: TR-data-004, TR-data-011, TR-input-012, TR-state-001, TR-state-002, TR-state-009, TR-enemy-005, TR-tower-006, TR-tower-013, TR-hero-004, TR-hud-006.

**ADR-0002 Catalogue Storage Format, Manifest and Validation** (Foundation). Decides: Resource vs JSON, strict field checks, manifest load on Android export, read-only proof, content tests.
Covers: TR-data-001, TR-data-002, TR-data-003, TR-data-005, TR-data-007, TR-data-013, TR-data-015, TR-enemy-001, TR-hero-014, TR-hud-016.

**ADR-0003 Fatal Error Path and Release-Safe Checks** (Foundation). Decides: fatal handler and screen, push_error vs assert, dev-error sink.
Covers: TR-data-006, TR-data-009, TR-state-011, TR-enemy-012.

**ADR-0004 Fixed-Tick Simulation Clock, Tick Order and Frame Order** (Foundation). Decides: tick rate and clamp, to_ticks, the one tick order, commands between ticks, pause, real-time presentation clocks.
Covers: TR-state-003, TR-state-004, TR-state-006, TR-state-007, TR-state-012, TR-state-014, TR-combat-009, TR-enemy-002, TR-enemy-003, TR-tower-005, TR-tower-010, TR-hero-003, TR-hero-011, TR-hero-013, TR-hud-005, TR-hud-007.

**ADR-0005 Stat Accessor and Read-Context Contract** (Foundation). Decides: accessor signature, key vocabulary and types, read at use, non-fatal lookups.
Covers: TR-data-008, TR-data-010, TR-enemy-006, TR-tower-003, TR-hero-005, TR-hud-011.

**ADR-0006 Input Adapter, Display Stretch and Platform Lifecycle** (Foundation). Decides: Godot event path, Control vs adapter order, emulation, safe area, stretch mode, pause and focus notifications.
Covers: TR-input-002, TR-input-003, TR-input-004, TR-input-005, TR-input-006, TR-input-013, TR-input-016, TR-state-010, TR-hud-002, TR-hud-003, TR-hud-014.

**ADR-0007 Determinism, Seeded RNG and Float Policy** (Foundation). Decides: seed injection, cosmetic RNG split, per-architecture baselines, scalar float vs Vector2.
Covers: TR-state-005, TR-combat-014, TR-enemy-007, TR-hero-006.

**ADR-0008 Headless Test Harness and gdUnit4 Configuration** (Foundation). Decides: fixtures, recording fakes, listener-count test, push_error reporting, bot equivalence.
Covers: TR-data-012, TR-input-014, TR-state-013, TR-combat-012, TR-enemy-014, TR-tower-014, TR-hero-012.

**ADR-0009 Battle Signal Contracts and View Allowlist** (Core). Decides: synchronous emit, commit before emit, typed signatures, view-only listeners.
Covers: TR-data-014, TR-state-008, TR-combat-010, TR-enemy-004, TR-tower-004, TR-tower-012, TR-hero-008, TR-hud-004, TR-hud-010, TR-hud-012.

**ADR-0010 Input Resolver Core and Signal Contract** (Core). Decides: pure resolver, hit-target registry, state machine, re-entrancy queue, payloads.
Covers: TR-input-001, TR-input-007, TR-input-008, TR-input-009, TR-input-010, TR-input-011, TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009.

**ADR-0011 Enemy Entity Kind, Roster and Combat Attachment** (Core). Decides: enemy object type, Health and Status attachment, roster ownership, path lookup.
Covers: TR-combat-001, TR-combat-002, TR-combat-005, TR-combat-006, TR-enemy-008, TR-enemy-009, TR-enemy-010, TR-enemy-011, TR-enemy-013.

**ADR-0012 Combat Delivery and Targeting API** (Core). Decides: deliver guards, targeting helpers, per-tick budget.
Covers: TR-combat-003, TR-combat-004, TR-combat-007, TR-combat-008, TR-combat-013, TR-tower-007, TR-hero-007.

**ADR-0013 Sim/Input Split and Command Result Codes** (Core). Decides: HeroSim/TowerSim vs Input pieces, command enums, gold ownership.
Covers: TR-tower-001, TR-tower-002, TR-tower-008, TR-tower-009, TR-hero-001, TR-hero-002, TR-hero-015.

**ADR-0014 Battle Field Rendering and Draw-Call Budget** (Presentation). Decides: single _draw nodes, pools, draw order, HUD budget.
Covers: TR-combat-011, TR-enemy-015, TR-tower-015, TR-hud-001, TR-hud-015.

**ADR-0015 Dev Telemetry: Gesture Log and Run Log** (Feature). Decides: gesture log harness, JSONL run log, per-run counters.
Covers: TR-input-015, TR-hero-009, TR-hud-013.

### Priority

**Must have before any code is written (Foundation, 8):** ADR-0001 to ADR-0008. At `standard`, which the 8 MVP GDDs run at, these are the critical set.

**Must have before the named system's first story (Core, 5):** ADR-0009 to ADR-0013. Four GDDs name these as prerequisites: Combat (ADR-0011 and ADR-0012: enemy object kind, Health and Status attachment), Hero and Tower (ADR-0013: HeroInput and TowerInput placement), Input (ADR-0010) and Battle HUD (ADR-0006: Control event order, input before ticks, `free()` timing).

**Can fold into the architecture or defer (2):** ADR-0014 (rendering and draw budget) can be settled at the first phone build, when draw calls are first measured. ADR-0015 (dev telemetry) can be a short ADR or a section of ADR-0010 and ADR-0013.

### Decisions made in this document that need no separate ADR

These follow directly from the GDDs and need only the cross-references above: no autoloads; simulation classes extend `RefCounted`; presentation never feeds the sim; commands run between ticks; progression systems own their save schema; code root `src/` with one folder per layer.

## Architecture Principles

1. **The battle is a plain function of its inputs.** `(catalogue, stage_id, seed, command script)` determines the result. The sim runs headless, with no scene, no clock and no engine event. Bots, tests and the phone build run the same code. Everything else in this document follows from that.
2. **No globals, no autoloads.** The App Root holds the catalogue. The Builder injects it, plus `halted()`, `fatal()`, the error sink and `to_ticks`, into whoever needs them. Dependency injection over singletons is a coding standard, and it is what makes each system unit-testable.
3. **Data drives gameplay, read at use time.** No gameplay number lives in code. Every value a modifier could ever touch goes through the one stat accessor and is never cached, so the Vertical Slice stat resolver drops in without call-site changes.
4. **Commit, then emit; observe, never steer.** State is final before any signal. Views and logs listen but cannot change a result, and a battle with all of them removed is identical.
5. **Fail loudly, once, and everywhere the same way.** No fallbacks in any build. One idempotent fatal handler. Checks that matter in release use injected handlers and `push_error`, never `assert`, because exports strip it.
6. **Verify post-cutoff engine behaviour before building on it.** Touch input, stretch, lifecycle, safe area and Control event order are unverified in the pinned reference. The ADR that depends on one verifies it against live 4.7 docs or a device first, then records the result in the engine reference.

## Open Questions

| ID | Question | Priority | Resolved by |
|---|---|---|---|
| QQ-01 | Tick driver: custom accumulator in `_process` or `_physics_process`; tick rate (60 Hz proposed); catch-up clamp value; behaviour on a frame stall. Does input arrive before `_process` on 4.7? | High | ADR-0004 |
| QQ-02 | Stretch mode and aspect (`project.godot` sets none; 4.7 changed new-project defaults), minimum width (360 dp proposed), whether a taller phone letterboxes or reveals the off-field entry. Layout rules L3, L5 to L7 depend on the answer. | High | ADR-0006, Mobile Platform GDD |
| QQ-03 | Catalogue format: typed `Resource` or JSON; how missing fields and fractional integers are caught; how read-only is enforced and snapshot-tested; proof it loads from an Android export. | High | ADR-0002 |
| QQ-04 | Type of `tower_id` and other IDs across signals: `StringName`, `String` or `int`. | Medium | ADR-0009 |
| QQ-05 | `Vector2` is documented as 32-bit in a stock build but unverified on 4.7. PinGeometry avoids `Vector2` methods until it is. Float results may differ between x86 and ARM, so bot baselines are kept per architecture. | Medium | ADR-0007 |
| QQ-06 | Lifecycle: which notifications fire on Android and iOS for pause and focus loss; Control event order against `_unhandled_input`; `free()` vs `queue_free()` timing inside input callbacks; moves and releases delivered after a `cancel` on focus return. | High | ADR-0006, ADR-0001, ADR-0004 |
| QQ-07 | Signal names that break the past-tense naming rule: `tap`, `ground_tap`, `pressed`, `idle`, `phase`, `waves_complete`. Rename (for example `tapped`, `ground_tapped`, `became_idle`, `phase_changed`, `waves_completed`) or record an exception. Settle before any code uses them. | Medium | ADR-0009, ADR-0010 |
| QQ-08 | Technical-director acceptance of four changes the GDDs make to earlier notes: composition root as a scene-free builder; ProjectileSpawner cut; the one tick order; path and slots moved from the stage scene to the Stage record. | High | ADR-0001, ADR-0004, ADR-0011 |
| QQ-09 | Where the Reduce Motion setting lives, before Settings (Alpha) exists. | Low | ADR-0001 |
| QQ-10 | Art bible §8 budgets a hit-flash shader; the Combat GDD uses none. | Low | technical-artist, ADR-0014 |
| QQ-11 | Unmeasured budgets: 60 draw calls, 256 MB, about 400 range checks under 2 ms per tick at the clamp, catalogue load at most 1000 ms median on an Adreno 5xx-class device. All need a device run at the first phone build. | Medium | ADR-0004, ADR-0014, performance-analyst |
| QQ-12 | No Mobile Platform & Performance GDD yet. A large top inset collides the HUD band with the arc's top panel and prompt. | Medium | Mobile Platform GDD |
| QQ-13 | `tests/README.md` is stale: gdUnit4 is now in `addons/` and the class cache is tracked in git. Whether the CI test command needs a prior `--import` step on a fresh clone. | Low | ADR-0008, `/test-setup` |
| QQ-14 | Stage tooling: a converter or editor for point-list stages before about 20 stages exist. | Low | tools-programmer, after MVP |
