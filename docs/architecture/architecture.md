# TowerRiot: Master Architecture

## Document Status
- Version: 3 (v2 revised after TD-ARCHITECTURE and LP-FEASIBILITY CONCERNS; v3 carries the 2026-11-03 cross-GDD fixes and closes QQ-09, QQ-19 and QQ-20. No gate has re-reviewed v2 or v3)
- Last Updated: 2026-11-03
- Engine: Godot 4.7.2 (GDScript, Mobile renderer, Godot Physics 2D). Pinned in `docs/engine-reference/godot/VERSION.md`.
- GDDs Covered (8 MVP systems): `data-config-pipeline`, `input-gesture-resolver`, `game-state-stage-flow`, `combat-damage`, `enemy-wave`, `tower-system`, `hero-system`, `battle-hud`. Context only: `game-concept`, `systems-index`.
- Vertical Slice and Alpha systems (14 of 22) have no GDD yet. They appear in the layer map as reserved slots with the seams MVP code must leave for them. This document is revised when those GDDs exist.
- ADRs Referenced: none exist yet. 11 are proposed (ADR-0001 to ADR-0011, numbers provisional until `/architecture-decision` assigns them). Version 1 proposed 15; four pairs were folded together to cut scope for a solo developer. Every contract below that a GDD defers to an ADR is marked **ADR-pending**: it is a working default, not a decision.
- Technical Requirements: 120, all registered in `docs/architecture/tr-registry.yaml` (TR-data, TR-input, TR-state, TR-combat, TR-enemy, TR-tower, TR-hero, TR-hud). Coverage by ADRs: 0 of 120.
- TD-ARCHITECTURE: 2026-11-03, REVISED after CONCERNS. v1 findings B1 to B4 and A3 (blocking) and A1, A2, A4 to A10 (advisory) applied in v2. A11 (acceptance of the four GDD amendments) waits for the ADRs (QQ-08). v2 has not been re-reviewed.
- LP-FEASIBILITY: 2026-11-03, REVISED after CONCERNS. v1 findings 1 to 7 (blocking) applied in v2, except finding 1's note that `sink` was invented: the Input GDD defines it as a TAP-only `bool`, and v2 keeps it with that type. Advisory 8 to 15 applied or carried into the named ADRs. v2 has not been re-reviewed.

## Engine Knowledge Gap Summary

The model's training covers Godot up to about 4.3. Versions 4.5, 4.6 and 4.7 are post-cutoff. The installed editor matches the pin (4.7.2).

| Domain | Risk for this project | Why | What it touches |
|---|---|---|---|
| Input (touch, mouse emulation) | **HIGH** | 4.7 mouse and keyboard no longer report device `0`. 4.6 split touch focus from keyboard focus. `modules/input.md` has no touch coverage, so every touch API claim in the GDDs is unverified. | Input adapter, resolver, HUD Controls, all hit targets |
| UI and display (stretch, safe area) | **HIGH** | 4.7 changed stretch defaults for new projects (`canvas_items` / `expand`). `project.godot` sets none, so the project inherits whatever the editor wrote. The 540x960 field space, layout rules L3 and L5 to L7 and the HUD layout all depend on it. | Display setup, every field-unit conversion, HUD layout |
| GDScript language | **HIGH** | 4.7: an override of a typed method inherits the return type and needs an explicit `return`. Packed array element writes skip the property setter. 4.5 added `@abstract` and variadic `...args`. Not new, but it bites here: lambdas capture locals by value in every Godot 4 version, and signal parameter types are not checked at `emit()`. | Every `.gd` file; base classes; signal handlers; the Builder's injected callables |
| Rendering (2D, Mobile renderer) | **MEDIUM** | 4.7: `CanvasItem` lines lose their antialiasing feather and look thinner. The Mobile renderer reference is desktop-leaning. The 60 draw-call budget is a proposal, not measured. | Field views, HUD `_draw`, path polygon |
| Resources and file access | **MEDIUM** | `duplicate()` on nested resources is deprecated for `duplicate_deep()` (4.5). `FileAccess.store_*` returns `bool` (4.4). | Catalogue snapshot test, run log, save/load (VS) |
| App lifecycle (pause, focus, background) | **HIGH, unreferenced** | The GDDs name `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_APPLICATION_PAUSED` and `NOTIFICATION_WM_WINDOW_FOCUS_OUT`. None is in the pinned reference. | Pause rule (TR-state-010), held-press clearing |
| Audio | **MEDIUM** (Alpha) | 4.7 `area_mask` default on `AudioStreamPlayer2D` changed to `0`. | Audio system, not before Alpha |
| Physics | **LOW** | The simulation uses no physics bodies or areas (Flow Rule 4). The 4.7 physics changes are all Jolt 3D. | None at MVP |
| Animation, Navigation, Networking | **N/A** | No skeletal animation, no pathfinding (the hero pins), no networking. | None |

Rule for this document: any engine behaviour that sits in a HIGH row is written as **NEEDS VERIFICATION** until an ADR author has checked it against the live 4.7 documentation or a device.

Owner of each HIGH row: Input and app lifecycle, ADR-0003 (verification spike first). UI and display, ADR-0003. GDScript language, ADR-0007 and the control manifest (QQ-15). Medium rows: rendering, ADR-0011; resources and file access, ADR-0002 and ADR-0010; audio, the Audio GDD (Alpha).

## System Layer Map

### Layers

```
┌────────────────────────────────────────────────────────────────────────────┐
│ COMPOSITION ROOT (exempt from the downward rule; nothing may depend on it) │
│   AppRoot (main scene) · Battle Builder · BattleWrapper (Clock) · Fatal UI │
├────────────────────────────────────────────────────────────────────────────┤
│ PRESENTATION   Battle HUD & Build UI · HeroInput · TowerInput · field      │
│                views · Visual Feedback (VS) · Menu (VS) · Onboarding (VS) · │
│                Audio (Alpha) · Settings & Accessibility (Alpha)            │
├────────────────────────────────────────────────────────────────────────────┤
│ FEATURE        Enemy & Wave · Tower (TowerSim + gold) · Hero (HeroSim +    │
│                Burst) · Stage Progression (VS) · Skill Points (VS) ·       │
│                Skill Tree (VS) · Hero Weapons (VS) · Synergies (VS/Alpha)  │
├────────────────────────────────────────────────────────────────────────────┤
│ CORE           Game State & Stage Flow (pure Flow machine, tick gate) ·    │
│                Combat & Damage · Stat & Modifier Resolution (VS)           │
├────────────────────────────────────────────────────────────────────────────┤
│ FOUNDATION     Data & Config (catalogue, validator, stat accessor) ·       │
│                Input & Gesture Resolver (+ adapter) · FatalLatch ·         │
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
5. Combat (Core) cannot name the enemy class (Feature) without an upward dependency. Combat therefore owns a small base class, `Targetable extends RefCounted` (`spawn_id`, `position`, `removed`, `health`, `status`), and Enemy & Wave's `Enemy` extends it. Combat's helpers take and return `Targetable`, so every field access is checked at parse time rather than by dynamic lookup on `Object`. Lists are built as `Array[Targetable]` from the start, because GDScript typed arrays are invariant and an `Array[Enemy]` cannot be passed where `Array[Targetable]` is expected. ADR-0009 ratifies this.
6. GDScript has no module boundaries and every `class_name` is global, so rules 1 to 5 are enforced by a layer-import lint in CI (ADR-0007), not by the language.

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
| 8 | Battle HUD & Build UI | MVP | Presentation | HudLogic, HudTopBand, HudField, HudModals |
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
| 21 | Settings & Accessibility | Alpha | Presentation | Owns Reduce Motion from Alpha. Until then it is the `reduce_motion` flag on the Input record |
| 22 | Cross-Tree Synergies (full) | Alpha | Feature | Reserved |

Note on requirement tags: the `Layer` column in `requirements-traceability.md` tags each *requirement* by the kind of work it asks for. It does not override the system layer above. Enemy & Wave, Tower and Hero requirements are tagged Core there because they run inside the tick; their module layer is Feature, as in the systems index.

### Seams MVP code must leave for later tiers

| Later system | Seam MVP code must keep |
|---|---|
| Stat & Modifier Resolution (VS) | Every modifiable value is read through the one stat accessor at use time, never cached (TR-data-008). The resolver replaces the accessor's internals with no call-site change. Modifier source tags are reserved now. |
| Save/Load (VS) | Progression systems expose `to_dict()` / `from_dict()` with a version field and never call Save. MVP has nothing to save, so no save code is written, but no MVP system may hold progression state in a global. |
| Stage Progression (VS) | Flow keeps its result (outcome, last wave started, lives left, Combat per-source damage) readable after the outcome (TR-state-006, TR-combat-005). |
| Skill Tree / Hero Weapons (VS) | Hero and Tower read stats through the accessor with a read context holding `def_id`, so a tree node changes a stat without touching Hero or Tower code. |
| Settings (Alpha) | Views read Reduce Motion from one place: the `reduce_motion` flag on the Input record (Data GDD), until Settings takes it over. |

## Module Ownership

Naming follows `project.yaml`: classes PascalCase, files snake_case, signals past tense. Signal names that break the past-tense rule are listed in QQ-07.

Code root is `src/` (Godot). Proposed folders, one per layer: `src/foundation/`, `src/core/`, `src/feature/`, `src/presentation/`, `src/root/`. Tests mirror them under `tests/unit/` and `tests/integration/`.

### Foundation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **Catalogue** (Data & Config) | The Ready catalogue: typed read-only records (Tower, Enemy, Wave, Stage, Hero, Burst, Input). The manifest. Load state (Unloaded, Loading, Ready, Failed). | `load(manifest) -> LoadResult`; typed record lookup by ID; `is_tower(id)`, `level_count(def_id)` (non-fatal) | Data files via manifest | `Resource` or JSON, `ResourceLoader` / `FileAccess` (MEDIUM; format is ADR-0002). `duplicate_deep()` for snapshot tests (4.5, MEDIUM) |
| **Validator** (inside Data & Config) | Error list `{code, source, record_id, field}`. Tiered checks. | `validate(records) -> Array[ValidationError]` | Catalogue records | None (plain GDScript) |
| **StatAccessor** (Data & Config) | Stat-key vocabulary and int/float type per key. Nothing else; no stored values. | `stat_int(ctx, key) -> int`, `stat_float(ctx, key) -> float`; a type mismatch or bad call goes to the injected failure handler | Catalogue; later Stat & Modifier | None |
| **InputResolver** | Hit-target registry, the four-state machine, the FIFO re-entrancy queue, the frozen winners of the current press. No clock, no scene. | `press`, `move`, `release`, `cancel_pointer`, `cancel`; `register`, `unregister`, `set_centre`, `set_enabled`; signals `pressed`, `tap`, `ground_tap`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `idle` (payloads in B2) | `drag_slop`, `tap_slop` from the Input record, passed to `create()` by the wrapper | None |
| **InputAdapter** (the only engine-facing input code) | Translation of engine events to the five resolver calls; edge and safe-area rejection; touch/mouse de-duplication; lifecycle `cancel()` calls | Emits `lifecycle_paused` (pause, focus loss) for Flow and HudLogic, `viewport_resized` for HudLogic | Godot input events, `DisplayServer`, viewport | `InputEventScreenTouch`, `InputEventScreenDrag` and the `canceled` flag (**HIGH, NEEDS VERIFICATION**); `_unhandled_input` vs `Control` ordering (**HIGH**); `Node.PROCESS_MODE_ALWAYS` (LOW); `DisplayServer.get_display_safe_area()` (**HIGH**); `Viewport.size_changed` (LOW); app lifecycle notifications (**HIGH**); mouse device ID change (4.7, **HIGH**) |
| **FatalLatch** | One per battle plus one on AppRoot. Pure: keeps the first cause, idempotent, `is_fatal()`. No screen, no scene, no catalogue. | `fatal(cause)` (injected as a `Callable`), `is_fatal()` | Nothing | `push_error` (LOW). `assert` is never used for release-relevant checks (stripped in exports) |
| *Mobile Platform (VS)* | Safe-area mapping, export presets, effect pooling, particle caps | Reserved | | `DisplayServer` (HIGH) |
| *Save/Load (VS)* | Save file, version field, migration | Reserved | | `FileAccess` (MEDIUM) |

### Core

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **Flow** (Game State, pure object) | Stage state machine (Build, Wave, Intermission, Paused, Won, Lost, Fatal). Lives. `intermission_left` as integer ticks. The stage result. The remembered phase while Paused. | `phase()`, `lives()`, `result()`, `in_build()`, `intermission_left`; commands `start_wave()`, `call_early()`, `pause()`, `resume()` (names proposed, QQ-18); signals `phase_changed`, `lives_changed`, `wave_called_early` | Enemy & Wave signals (`wave_cleared`, `waves_complete`, `enemy_leaked`); injected `cancel_input()`, `wave_index()` and the battle FatalLatch; the adapter's lifecycle signal (wired by the Builder's wrapper step) | None |
| **Combat** | `Targetable` base class, `DamageEvent` value, one Health and one Status per target, per-source damage counters. | `deliver(event) -> float`; `apply_slow`; `speed_factor`; `tick_status(roster)`; `first_in`, `nearest_in`, `all_in_radius`; `dealt_by_id`, `dealt_by_kind`, `dealt_total`, `hero_share`; `is_dead`, `hp_left`; `report_attack`; signals `attack_fired`, `damage_applied` | Values passed in by callers; `to_ticks` and `dt` injected at build | None (pure) |
| *Stat & Modifier (VS)* | Modifier stack, fixed evaluation order | Behind `StatAccessor` | Catalogue, tree nodes | None |

### Feature

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **EnemyWave** | Roster (sole owner of enemies), wave state machine, cached positions along the path polyline, `spawn_id` counter | `roster()`, `targets()` (both in `spawn_id` order, valid for the slot only); `advance(tick)`, `reap()`, `start_next_wave()`, add-enemy step; signals `enemy_leaked(lives_cost)`, `enemy_killed(bounty)`, `wave_cleared(intermission_duration)`, `waves_complete` | Stage and Wave records (direct), stats via accessor, Combat attach call, injected `halted()` and error sink | None in the sim. Views use `CanvasItem._draw` (see Presentation) |
| **TowerSim** | Gold (non-negative int), slots, towers, per-tower `cooldown_left` (ticks) | `build(slot_index, tower_id) -> BuildResult`, `upgrade(slot_index) -> UpgradeResult`, `tick()`, `slot_state()`, `early_call_bonus()`, `slows_applied()`, `gold()`; signals `gold_changed`, `tower_built`, `tower_upgraded` | `slot_positions` from the Stage record; accessor; `enemy_killed` straight from EnemyWave and `wave_called_early` from Flow (both wired by the Builder); injected `targets()` and `halted()`; Combat helpers | None |
| **HeroSim** | Hero position, pin target, pin state, burst state, cooldown, telegraph, run counters | `pin(pos) -> PinResult`, `burst(pos) -> BurstResult`, `tick()`, read-only queries (`position`, `pin_target`, `pin_state`, `burst_state`, `cooldown_left`), counters; signals `hero_pinned`, `burst_started` | Stage record (`hero_start`, `pin_rect`, `pin_exclusion`), accessor, Combat, injected `targets()`, `halted()`, `in_build()` and `left_handed` | None |
| **PinGeometry** | Pure clamp and validity maths in float scalars | `is_valid(pos) -> PinResult` (`OUT_OF_BOUNDS`, `BUTTON_ZONE` or `OK`, per Hero Rule 14), `clamp(pos)` | Pin rect and exclusion segments | None (avoids `Vector2` methods on purpose, see QQ-05) |
| *Stage Progression, Skill Points, Skill Tree, Hero Weapons, Synergies (VS/Alpha)* | Reserved | | | |

### Presentation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **HudLogic** | HUD presentation state (button arm model, modal press model, arc state, range rings, snapshot). Registers every HUD disc, listens to gestures and issues commands. No gameplay state. | `advance(ms)`, `modal_press`, `modal_move`, `modal_release`, `modal_cancel_pointer`, `modal_cancel`, `modal_changed`, `burst_button_centre()`, view-model reads | Resolver, TowerInput signals, Flow, TowerSim, HeroSim, EnemyWave, Combat (read-only), accessor for costs and Burst `cooldown`, injected `dt` and `to_ticks` | None |
| **HudTopBand** | Display-only `Control`s for gold, lives, pips and the next-wave line, which ignore input | None | HudLogic | `Control`, `mouse_filter` (HIGH, 4.6 dual focus) |
| **HudField** | A `Node2D` that only draws, with one `_draw` for arc, chip, Start/Call, burst button art and digit, all rings and the prompt, redrawn on a quantised key and while a timed visual runs | None | HudLogic, HeroInput (`aim_state()`, `button_press()`, `cooldown_digit()`) | `CanvasItem._draw` (MEDIUM, 4.7 line feather) |
| **HudModals** | Result and Paused `Control`s, built once and toggled visible, forwarding presses, moves and releases to HudLogic; toggled on `modal_changed` | None | HudLogic | `Control` input (HIGH, ADR-0003) |
| **HeroInput** | Aim state machine (Idle, Cancelling, Live), aim-point re-clamp, cancel hysteresis | `update()`, `aim_state()`, `aim_point()`, `button_press()`, `cooldown_digit()` | Resolver signals, HeroSim queries, `burst_button_centre()` from the HUD | None |
| **TowerInput** | Slot and chip discs, `ChipWindow` | `slot_tapped`, `tower_inspected`, `chip_state()` | Resolver, TowerSim, Flow `phase_changed` | None |
| **ChipWindow** | Real-time upgrade-chip timing | `advance(ms)` | Fed by the wrapper each frame | None |
| **Field views** (enemy, tower, combat, path, hero) | Pools, draw order, flash markers (16 max), enemy view pool (at least 48). The hero view draws the reticle, reach ring, kill preview and Ready ticks | None | `roster()`, `slot_state()`, Combat view signals, HeroInput and HeroSim reads | `CanvasItem._draw`, `draw_polyline` or a baked polygon (MEDIUM, **NEEDS VERIFICATION** for 90 degree corners at width 72) |
| **RunLog / GestureLog** (dev only) | JSONL records, gesture records | Injectable sink | Signals only | `FileAccess` append (MEDIUM; check the `bool` return). Decided in ADR-0010 and ADR-0008 |

### Composition Root

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **AppRoot** (main scene, no autoload) | App states Boot, InStage, Fatal (Game State GDD). The Ready catalogue for the session. The app-level FatalLatch. The retry latch. | Starts the catalogue load; builds battles and drops them | Catalogue, FatalLatch | `Node`, `PackedScene`, `Object.free()` vs `queue_free()` timing for the wrapper on retry (**MEDIUM, NEEDS VERIFICATION**), `weakref()` (LOW) |
| **Builder** (`build(catalogue, stage_id, seed, fatal_handler)`) | Nothing persistent. Creates the per-battle FatalLatch first, then constructs one `Battle` and makes every connection. | Returns a `Battle` | Every sim module | `Signal.connect(Callable)` (LOW). No `CONNECT_DEFERRED` on gameplay signals (TR-enemy-004). Injected callables are method Callables only: no lambda or `bind()` that captures a sim object (TD-ARCHITECTURE B4; Callable reference semantics **NEEDS VERIFICATION**, QQ-17) |
| **BattleWrapper** (scene) | The Clock: real-time accumulator, catch-up clamp (max ticks per frame), accumulator zeroed on `phase_changed(PAUSED)`. Also the input adapter, views and the HUD. Absent headless. | None | Battle, adapter | `Node._process` (LOW); `_process` vs `_physics_process` decided in ADR-0004 |
| **Fatal screen** (scene) | Catalogue-free, guaranteed to load. Shown by AppRoot. | None | AppRoot FatalLatch cause (development builds show it) | `PackedScene` (LOW) |

### Dependency diagram (MVP)

```
                          ┌──────────── AppRoot ────────────┐
                          │ owns Catalogue, FatalLatch      │
                          └──────────────┬──────────────────┘
                                         │ build(catalogue, stage, seed, fatal)
                                         ▼
 ┌────────────────────────────── Battle (plain object) ───────────────────────────┐
 │                                                                                │
 │   Flow ◄──signals── EnemyWave ──attach/targets──► Combat ◄──deliver── TowerSim │
 │    │  ▲                │  ▲                          ▲  ▲                │     │
 │    │  └─ phase,lives   │  └── roster()/targets() ────┘  └── deliver ── HeroSim  │
 │    │                   │                                                  ▲     │
 │    └─ halted(), in_build(), targets() injected into the sims ─────────────┘     │
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
Engine delivers input events (before this frame's _process; NEEDS VERIFICATION, ADR-0003 spike)
  InputAdapter ──► InputResolver ──► signals ──► HeroInput / TowerInput / HudLogic
                                                    │ commands: pin, burst, build, upgrade,
                                                    │ start_wave, call_early  (run NOW, between ticks)
BattleWrapper._process(delta):
  1. Advance real-time models:  HudLogic.advance(ms), ChipWindow.advance(ms), HeroInput.update()
  2. Clock: accumulator += delta; ticks_owed = min(floor(acc / dt), MAX_TICKS_PER_FRAME)
  3. for each owed tick:  battle.tick(dt)
       Battle.tick itself returns at once unless Flow.phase() is WAVE or INTERMISSION
       and halted() is false. The gate lives in the sim, so it holds headless too.
  4. Refresh views from read-only queries (roster, slot_state, hero queries, HUD view-models)
```

| Data | Producer | Consumer | Kind |
|---|---|---|---|
| Touch/mouse events | Godot | InputAdapter | Engine callback |
| Five resolver calls | InputAdapter | InputResolver | Synchronous call |
| Gesture signals | InputResolver | HeroInput, TowerInput, HudLogic | Signal (synchronous) |
| Commands | HeroInput, TowerInput, HudLogic, bots | HeroSim, TowerSim, Flow | Synchronous call, **only between ticks**, returns a result enum |
| `tick(dt)` | Clock (BattleWrapper) | Battle | Synchronous call; gated inside Battle |
| View reads | Views | Sim modules | Read-only query |

Rule: commands run from the input call stack, before the frame's ticks, so the bonus the HUD shows equals the bonus paid (TR-hud-005). Whether input is delivered before `_process` on 4.7 is **NEEDS VERIFICATION**. ADR-0003 verifies the engine's event order in a spike; ADR-0004 owns the frame order that relies on it. `MAX_TICKS_PER_FRAME` is an explicit output of ADR-0004.

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
| `lives_changed(current)`, `phase_changed(value)`, `wave_called_early(seconds_left)` | Flow | HUD, TowerSim (`wave_called_early`, and `phase_changed` for the chip), BattleWrapper (zeroes the accumulator on PAUSED), views | The GDD names the signal `phase_changed`; renamed here because a member and a signal cannot share a name and Flow also needs a `phase()` read (TD-ARCHITECTURE B1) |
| `gold_changed`, `tower_built`, `tower_upgraded` | TowerSim | HUD, views | Commit first, `gold_changed` then the tower signal; a refusal emits nothing |
| `hero_pinned`, `burst_started` | HeroSim | Views, HUD | After state set; handlers never issue commands |
| `attack_fired`, `damage_applied` | Combat | Combat view, audio (Alpha) | View-only; listeners never call `deliver` |
| Gesture signals | InputResolver | HeroInput, TowerInput, HudLogic | Re-entrant calls queue FIFO and drain in the outermost call |

Rules for all of them (ADR-0006):
1. **Commit, then emit.** State is final before the first listener runs.
2. **Gameplay does not depend on listeners.** A battle with every view listener removed produces identical state (TR-tower-012, TR-hud-004).
3. **Wiring signals** (the ones in the first six rows that the sim itself consumes) are connected only in the Builder, never deferred.
4. **View allowlist.** A test fails if any battle signal has no listener, except signals on a named allowlist (TR-state-013).
5. Signals declare typed parameters, but GDScript does not check them at `emit()`, and a `connect` with a mismatched Callable fails only at runtime. The real guard is the listener-count test plus recording fakes that assert payloads, not only call counts (ADR-0007). The type of `tower_id` is undecided (QQ-04).

### 4. Initialisation order

```
Engine starts main scene ──► AppRoot._ready
  1. AppRoot FatalLatch ready; the catalogue-free fatal scene is loadable. AppRoot state: Boot
  2. Catalogue.load(manifest)         Unloaded ─► Loading ─► Ready | Failed
       Failed ─► fatal screen (no fallbacks, no save access). Includes tap_slop ≤ drag_slop (Data Rule 7)
  3. (VS) Save/Load boot: inject loaded progression into progression systems
  4. AppRoot holds Ready catalogue, picks stage_id and seed. AppRoot state: InStage
  5. Builder.build(catalogue, stage_id, seed, fatal_handler)
       a. Create the per-battle FatalLatch first, so a fatal during build has somewhere to land
       b. Validate stage inputs
       c. Construct Flow, Combat, EnemyWave, TowerSim, HeroSim
       d. Make every signal connection; inject halted(), in_build(), targets(), cancel_input(),
          left_handed, to_ticks, wave_index(), the Hero and Burst IDs and the error sink (method Callables only, no capturing lambdas)
       e. Return Battle (headless-safe: no node touched)
  6. BattleWrapper builds InputResolver.create(drag_slop, tap_slop) (null: fatal), sets battle.set_input_cancel(resolver.cancel),
     and adds, in order, InputAdapter, Clock, TowerInput, HudLogic, HeroInput (reads burst_button_centre()), then HudTopBand, HudField, HudModals and the field views, around the Battle
  Flow opens in Build, emitting nothing, so HudLogic and TowerInput read phase() when built in step 6.
```

Dependency note: the stat accessor cannot be used before step 2 finishes. The resolver reads its slops directly from the Input record, not through the accessor (TR-input-012).

### 5. Retry and teardown path

```
Result screen "Retry" pressed
  ─► sets idempotent retry latch on AppRoot (does NOT free the caller)
AppRoot next frame:
  1. If Fatal: show fatal screen, stop
  2. Stop Clock;  InputResolver.cancel()
  3. Free the wrapper and its nodes (adapter, HUD, views). Drop every reference to the Battle and the
     resolver: they are RefCounted, so they cannot be freed, only released. A weakref to the old
     Battle must then read null (TR-state-009, TR-enemy-008, TR-tower-013). That holds only if no
     reference cycle exists: no lambda or bind() capturing a sim object, no sim back-reference to Battle.
  4. Builder.build(...) again with the SAME catalogue (it is held by AppRoot)
```
Retry resets nothing in place. It rebuilds. `free()` vs `queue_free()` timing for the wrapper nodes, and whether a method Callable holds a strong reference, are **NEEDS VERIFICATION** (ADR-0001, QQ-17).

### 6. Pause and focus path

```
App loses focus / backgrounds  (notification names NEEDS VERIFICATION, ADR-0003)
  InputAdapter ─► resolver.cancel()  and forwards one lifecycle signal
  Flow: remember phase, enter PAUSED, call the injected cancel_input() (finds Idle, does nothing), emit phase_changed(PAUSED)
  Battle.tick now returns at once (the in-sim gate); BattleWrapper zeroes its accumulator
  A finger held across the pause stays dead until lifted; the resume tap reaches nothing beneath
  Resume: Flow restores the remembered phase;  walk and telegraph resume exactly (TR-hero-013)
```
Real-time models (button arming, chip window) freeze while Paused (TR-hud-007).

### 7. Fatal path

```
Any of: catalogue load failure · bad accessor call · stage scene that fails to load · bad stage input
  ─► fatal(cause)   (injected Callable; idempotent; keeps the FIRST cause)
       latches the per-battle FatalLatch and the AppRoot FatalLatch; Flow enters FATAL and emits
       phase_changed(FATAL); the current tick halts; a partial build is discarded;
       AppRoot (state Fatal) shows the catalogue-free fatal screen and never opens saves
  Development builds name each error by file, record and field.
```
GDScript has no exceptions, so after `fatal` every caller checks `halted()` and returns (TR-state-011). The injected `halted()` is `Battle.halted()`: true when Flow is WON, LOST or FATAL, or the battle FatalLatch is set. It is false while PAUSED; the tick gate, not `halted()`, stops time during a pause.

### 8. Save/load path (Vertical Slice, reserved)

Not built at MVP. The contract MVP code must respect: progression systems own their schema, expose `to_dict()` and `from_dict()` with a `version` field, and never call Save. Save owns the file and injects loaded state at boot (step 3 above). The serialised state will be skill points, tree nodes, weapons, stars and settings. No battle state is ever saved, because a battle is rebuilt from `(catalogue, stage_id, seed)`.

### 9. Dev telemetry path

Development builds only. A gesture-log harness listens to resolver signals; a run log appends JSON lines to `user://run_log.jsonl` through an injectable sink. A write failure is non-fatal and release builds never write (TR-hud-013, TR-input-015). Both listen only; neither can change a result.

### 10. Frame budget (proposal, unmeasured)

`project.yaml` sets 60 fps (16.6 ms), 60 draw calls and 256 MB, with a 30 fps floor on low-end Android. This split is a starting proposal for ADR-0004 and ADR-0011 to confirm on a device at the first phone build (QQ-11).

| Slice | Budget at 60 fps | Notes |
|---|---|---|
| Input, resolver, commands | 0.5 ms | Event count is small (one finger) |
| Simulation ticks | 4.0 ms total | Normal frame: one tick. At the catch-up clamp, `MAX_TICKS_PER_FRAME` ticks must fit here, so ADR-0004 sets the clamp from the measured per-tick cost. Combat's worst case (about 400 range checks per tick) is estimated under 2 ms per tick, unmeasured |
| Views and HUD (`_draw`, view-model refresh) | 3.0 ms | HUD about 8 of 60 draw calls (max 12), at most 3 text draws |
| Engine, rendering submit, OS | 7.0 ms | Mobile renderer, 2D only |
| Headroom | 2.1 ms | GC-free GDScript still has allocation spikes; keep it |

## API Boundaries

Contracts are GDScript sketches. Where a GDD fixes a name, signature or payload, this section copies it verbatim; the GDD stays the source. Where a GDD leaves one open, the sketch proposes a name and marks it **proposed**, and the named ADR decides. Engine types used (`RefCounted`, `Resource`, `Callable`, `Signal`, `StringName`, `Node`) are stable since 4.0, with no signature change in 4.5 to 4.7 per `breaking-changes.md`.

All simulation classes extend `RefCounted`, never `Node`. A freed `Node` cannot honour `removed`, and a `Node`'s built-in `position` would collide with Combat's cached one (TR-combat-002).

Every command result enum puts `OK = 0` first; the remaining values are listed in the GDD's check order. Code compares results to `OK` explicitly. A truthiness test (`if result:`) is forbidden, because `OK` is `0` and therefore falsy.

### B0. Shared types (ADR-0002, ADR-0005, ADR-0009)

| Type | Base | Owning file (proposed) | Fields or role | Decided by |
|---|---|---|---|---|
| `Catalogue` | `RefCounted` | `src/foundation/data/catalogue.gd` | Holds every record by ID after a Ready load; read-only by contract | ADR-0002 |
| `LoadResult` | `RefCounted` | same | `ok: bool`, `errors: Array[ValidationError]` | ADR-0002 |
| `ValidationError` | `RefCounted` | `src/foundation/data/validation_error.gd` | `code: StringName`, `source: String`, `record_id: StringName`, `field: StringName` | ADR-0002 |
| Record classes: `TowerRecord`, `EnemyRecord`, `WaveRecord`, `StageRecord`, `HeroRecord`, `BurstRecord`, `InputRecord` | `Resource` or `RefCounted` (format is ADR-0002) | `src/foundation/data/records/` | `id: StringName` plus each GDD's fields. `StageRecord` holds `path_points`, `slot_positions`, `path_width`, `requires_bend`, `early_call_seconds_per_gold`, `hero_start`, `pin_rect`, `pin_exclusion`, `scene_ref`. `InputRecord` holds `drag_slop`, `tap_slop`, `edge_reject_margin`, `left_handed`, `reduce_motion` | ADR-0002 |
| `ReadContext` | `RefCounted` | `src/foundation/data/read_context.gd` | `def_id: StringName`, `level: int = 0`, `live_entity: Object = null`. **One reused instance per caller** (per enemy, per tower slot, one for the hero), never one per read, so a tick allocates nothing | ADR-0005 |
| `Targetable` | `RefCounted` | `src/core/combat/targetable.gd` | `spawn_id: int`, `position: Vector2` (cached once per tick), `removed: bool`, `health: Health`, `status: Status` | ADR-0009 |
| `Enemy` | `Targetable` | `src/feature/enemy_wave/enemy.gd` | Adds `def_id: StringName`, `distance: float`, its `ReadContext` | ADR-0009 |
| `DamageEvent` | `RefCounted` | `src/core/combat/damage_event.gd` | `target: Targetable`, `amount: float`, `source_kind: Combat.SourceKind`, `source_id: StringName` | ADR-0009 |
| `StageResult` | `RefCounted` | `src/core/flow/stage_result.gd` | `outcome: Flow.Phase` (WON, LOST or FATAL), `last_wave_started: int`, `lives_left: int`, per-source damage copied from Combat | ADR-0006 |
| `Battle` | `RefCounted` | `src/root/battle.gd` | Read-only members: `flow: Flow`, `combat: Combat`, `enemy_wave: EnemyWave`, `tower_sim: TowerSim`, `hero_sim: HeroSim`, `fatal_latch: FatalLatch` | ADR-0001 |

IDs are `StringName` throughout as the working default. QQ-04 decides whether that holds for `tower_id` in signals.

### B1. Stat accessor (ADR-0005)

```gdscript
class_name StatAccessor extends RefCounted

## Returns the value for key, typed. The key's declared type must match the call:
## stat_int on a float key (or the reverse) is a bad call. Never cache the result,
## except max_hp when seeding Health.
func stat_int(ctx: ReadContext, key: StringName) -> int
func stat_float(ctx: ReadContext, key: StringName) -> float

## Non-fatal lookups. Call these first when an ID or level is not already trusted.
func is_tower(id: StringName) -> bool
func level_count(def_id: StringName) -> int
```
Invariants: a bad call (unknown or inapplicable key, wrong type, bad level, unresolved `def_id`) calls the injected failure handler, which survives release builds, so it is not an `assert`. After a bad call the method returns `0` or `0.0` and the caller must check `halted()` before using it. Two typed methods replace version 1's `Variant` return, so callers keep static typing (TD-ARCHITECTURE A9).

### B2. Input resolver (ADR-0008, ADR-0003)

Copied from the Input & Gesture Resolver GDD.

```gdscript
class_name InputResolver extends RefCounted
enum Accepts { TAP, DRAG }
const NONE := -1

static func validate(drag_slop: float, tap_slop: float) -> bool
static func create(drag_slop: float, tap_slop: float) -> InputResolver   # null when invalid

# Driven only by the adapter (or tests). Positions are 540x960 field units.
func press(pointer: int, pos: Vector2) -> void
func move(pointer: int, pos: Vector2) -> void
func release(pointer: int, pos: Vector2) -> void
func cancel_pointer(pointer: int) -> void
func cancel() -> void

# Registry. Legal in any state, including inside handlers; effective at once.
func register(centre: Vector2, radius: float, accepts: Accepts, priority: int, sink: bool = false) -> int
func unregister(id: int) -> void
func set_centre(id: int, centre: Vector2) -> void
func set_enabled(id: int, enabled: bool) -> void

signal pressed(best_tap: int, best_drag: int, p: Vector2)
signal tap(best_tap: int, p: Vector2)
signal ground_tap(p: Vector2)
signal drag_started(best_drag: int, press_pos: Vector2, p: Vector2)
signal drag_moved(best_drag: int, press_pos: Vector2, p: Vector2)      # one per input call, never per frame
signal drag_ended(best_drag: int, press_pos: Vector2, release_pos: Vector2)
signal drag_cancelled(best_drag: int)
signal idle()                                                          # last signal of every exit to Idle
```
Invariants: ids start at 1 and are never reused; `NONE` marks an absent winner. `sink` is TAP-only: the target absorbs taps its owner ignores, without raising the press's slop. One active pointer. Winners and their discs are frozen at press (tie-break: priority, then squared distance, then id). Gesture calls made inside a handler queue FIFO and drain synchronously in the outermost call. No clock, no scene tree, no engine events. Non-finite positions and radii are dropped with `push_error`. Names that break the past-tense rule (`tap`, `ground_tap`, `pressed`, `idle`) are QQ-07, to be settled before ADR-0008 is written, because the GDD's tests already use them.

### B3. Input adapter (ADR-0003)

```gdscript
class_name InputAdapter extends Node        # process_mode = PROCESS_MODE_ALWAYS
signal lifecycle_paused()                   # pause and focus loss only; the wrapper connects it to Flow.pause() and HudLogic.modal_cancel()
signal viewport_resized()                   # a resize cancels input without pausing; connected to HudLogic.modal_cancel()
# Contract: every forwarded press is followed by a release, cancel_pointer or cancel() for that
# index, and the first closes it, even when a Control with mouse_filter = STOP lies under the drag.
# Calls resolver.cancel() on pause, focus loss and viewport resize.
```
Everything in this block is **NEEDS VERIFICATION** against live 4.7 docs: event path (`_unhandled_input` vs `_input`), `InputEventScreenTouch.canceled`, emulation settings, pointer-index collision, the 4.7 mouse device ID, `get_display_safe_area()` units. ADR-0003 decides stretch mode, aspect, minimum width and tall-phone behaviour itself; the Mobile Platform GDD (Vertical Slice) inherits the decision rather than blocking it (TD-ARCHITECTURE A3).

### B4. Battle and Builder (ADR-0001, ADR-0004)

```gdscript
class_name Battle extends RefCounted
func tick(dt: float) -> void      # the ONLY way simulation time advances.
                                  # Returns at once unless flow.phase() is WAVE or INTERMISSION
                                  # and halted() is false.
func halted() -> bool             # flow outcome WON, LOST or FATAL, or fatal_latch set
func set_input_cancel(cancel: Callable) -> void   # wrapper only; never set headless
func cancel_input() -> void       # public, guarded with is_valid(); Flow and AppRoot both call it
# Reads for the wrapper, which injects them into HeroInput and HudLogic (the builder never sees those):
# left_handed, hero_id, burst_id, dt, to_ticks, in_build
# Strong typed fields: every sim, the FatalLatch and the one per-battle StatAccessor (Flow Rule 2a)

class_name BattleBuilder extends RefCounted
static func build(catalogue: Catalogue, stage_id: StringName, seed: int, fatal_handler: Callable) -> Battle
```
Invariants: `build` touches no node, so bots and tests call it headless. It creates the per-battle FatalLatch first, then makes every connection in one function. It is never called from inside a signal. Injected callables are method Callables only: no lambda or `bind()` that captures a sim object, and no sim object holds a reference back to `Battle`, so dropping the `Battle` frees everything and the weakref test passes. Gameplay classes never read `Engine`, `Time`, `OS`, a timer or `await`.

### B5. Flow (ADR-0004, ADR-0006)

```gdscript
class_name Flow extends RefCounted
enum Phase { BUILD, WAVE, INTERMISSION, PAUSED, WON, LOST, FATAL }
func phase() -> Phase
func lives() -> int
func result() -> StageResult         # readable after the outcome until the battle is dropped
func in_build() -> bool
func tick() -> void
var intermission_left: int           # integer ticks, never float subtraction
# Commands (between ticks). The GDD names the actions, not the methods; names are proposed (QQ-18).
func start_wave() -> StartResult     # Start Wave in BUILD; a second tap finds no BUILD and is ignored
func call_early() -> CallResult      # Call during INTERMISSION; a call at 0 is ignored with no signal
func pause() -> void
func resume() -> void
signal phase_changed(value: Phase)   # Renamed from phase in the GDDs too (2026-11-04): signal phase plus func phase() fails to parse on 4.7.2
signal lives_changed(current: int)
signal wave_called_early(seconds_left: float)
```
Commit order (Rule 15): set state, then act (`start_next_wave()`, or the tick gate stops time and `cancel_input()`), then emit in order, stopping if Fatal latched during an emit. `phase_changed` fires on every state change. FATAL can replace WON, LOST and PAUSED. FATAL is a `Phase` value because Rule 15 has `phase_changed` name Won, Lost, Paused and Fatal, and Tower's chip listens for Fatal. AppRoot's own states (Boot, InStage, Fatal) are separate and live on AppRoot. Retry is an AppRoot latch, not a Flow command.

### B6. Combat (ADR-0009)

Copied from the Combat & Damage GDD.

```gdscript
class_name Combat extends RefCounted
enum SourceKind { TOWER, HERO, BURST }

func deliver(event: DamageEvent) -> float                            # applies min(amount, hp); only inside a tick
func apply_slow(enemy: Targetable, strength: float, seconds: float) -> void   # Combat converts seconds to ticks
func speed_factor(enemy: Targetable) -> float
func tick_status(roster: Array[Targetable]) -> void
func first_in(list: Array[Targetable], origin: Vector2, max_range: float) -> Targetable     # lowest spawn_id on ties
func nearest_in(list: Array[Targetable], origin: Vector2, max_range: float) -> Targetable
func all_in_radius(list: Array[Targetable], impact: Vector2, radius: float) -> Array[Targetable]
func is_dead(enemy: Targetable) -> bool
func hp_left(enemy: Targetable) -> float
func report_attack(source_kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float) -> void
func dealt_by_id(id: StringName) -> float
func dealt_by_kind(kind: SourceKind) -> float
func dealt_total() -> float
func hero_share() -> float
signal attack_fired(source_kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
signal damage_applied(event: DamageEvent, applied: float, position: Vector2, killed: bool, spawn_id: int)
```
Invariants: every HP change goes through `deliver`. Guards run in a fixed order (removed, amount, dead) and report named `push_error` codes. The parameter is `max_range` because `range` is a GDScript global. Combat reads no catalogue data. Helpers never mutate the list and skip the dead. View signals carry copied positions, and listeners never call `deliver`. The list parameter types (`Array[Targetable]`) are this document's proposal; the GDD leaves list typing to the ADR.

### B7. Enemy and Wave (ADR-0009)

```gdscript
class_name EnemyWave extends RefCounted
func advance(tick: int) -> void
func reap() -> void
func start_next_wave() -> void              # parameterless; commits at wave_tick 0
func roster() -> Array[Targetable]          # spawn_id order; caller must not hold it past its slot
func targets() -> Array[Targetable]         # targetable only: centre inside the 540x960 field
func wave_index() -> int                    # view-only read
func got_through_by_type() -> Dictionary    # view-only read
signal enemy_leaked(lives_cost: int)
signal enemy_killed(bounty: int)
signal wave_cleared(intermission_duration: float)
signal waves_complete()                     # breaks the past-tense rule: QQ-07
```
`wave_index()` is 1-based: 0 before the first start, set when `start_next_wave` commits, unchanged by a clear or an outcome (Rule 14). `got_through_by_type()` counts a leak before `enemy_leaked` fires, so the fatal leak is in the result (Rule 10). The enemy stays a valid reference after removal (`removed` is set, the object is not freed). Lists are built as `Array[Targetable]` from the start, since typed arrays are invariant.

### B8. TowerSim and HeroSim commands (ADR-0010)

```gdscript
class_name TowerSim extends RefCounted
enum BuildResult { OK, HALTED, BAD_SLOT, BAD_TOWER, SLOT_OCCUPIED, NO_GOLD }
enum UpgradeResult { OK, HALTED, BAD_SLOT, NO_TOWER, MAX_LEVEL, NO_GOLD }
func build(slot_index: int, tower_id: StringName) -> BuildResult
func upgrade(slot_index: int) -> UpgradeResult
func gold() -> int
func slot_state() -> Array                  # per slot: tower_id, level, cooldown_left
func early_call_bonus(seconds_left: float) -> int   # pure; the payout and the HUD's "Call +N" share it (Rule 17)
func slows_applied() -> int                 # view-only read for the result
signal gold_changed(current: int)
signal tower_built(slot_index: int, tower_id: StringName)   # tower_id type: QQ-04
signal tower_upgraded(slot_index: int, level: int)

class_name HeroSim extends RefCounted
enum PinResult { OK, HALTED, BAD_POSITION, OUT_OF_BOUNDS, BUTTON_ZONE }
enum BurstResult { OK, HALTED, BUILD_PHASE, NOT_PINNED, NOT_READY, BAD_POSITION, OFF_FIELD, OUT_OF_REACH }
func pin(pos: Vector2) -> PinResult
func burst(pos: Vector2) -> BurstResult
signal hero_pinned(position: Vector2)
signal burst_started(aim_point: Vector2, telegraph_ticks: int)
```
Invariants: commands run only between ticks. State is checked before geometry. A refusal mutates and emits nothing. All stats a command needs are read before any mutation, so a bad read halts with nothing half done. After `OK`, the enum lists checks in the GDD's order. TowerInput's `slot_tapped` and `tower_inspected` are signals from TowerInput, not reads.

### B9. Injected values and callables (ADR-0001)

| Name | Injected into | Meaning |
|---|---|---|
| `halted() -> bool` | EnemyWave, TowerSim, HeroSim | `Battle.halted()`. Checked after every accessor read and every signal. HudLogic tests `phase() == FATAL` instead, since its snapshot runs after an outcome, when `halted()` is already true. |
| `in_build() -> bool` | HeroSim, HeroInput, HudLogic | True in BUILD and while PAUSED from BUILD. HeroSim refuses the burst on it and places a pin at once. |
| `targets() -> Array[Targetable]` | TowerSim, HeroSim | EnemyWave's `targets()`, so Tower and Hero never reference EnemyWave (Tower Rules 9, 13; Hero Rule 4). |
| `cancel_input() -> void` | Flow | A method on `Battle` that forwards to the cancel the wrapper set, so Flow never references the resolver (TR-state-007). Guards with `is_valid()`, since an unguarded call on an unset Callable is a script error (QQ-17). Headless nothing is set, so it does nothing. |
| Hero record ID | HeroSim, HeroInput | The one Hero record (Hero Rules 2, 8). |
| `burst_id` | HeroSim, HeroInput, HudLogic | From the Hero record: HeroInput reads burst damage for the kill preview, and the HUD reads Burst `cooldown` for the wedge, through the accessor without naming Burst data. |
| `wave_index() -> int` | Flow | EnemyWave's read, so Flow's result names the last wave started and Flow keeps no wave count (Flow Rule 15). |
| `left_handed: bool` | HeroSim, HeroInput, HudLogic | From the Input record, fixed per battle (Hero Rule 2, TR-hero-004). |
| `fatal(cause: String) -> void` | Builder, accessor, all sims | Sets the battle FatalLatch and the AppRoot FatalLatch. Idempotent. |
| `dev_error(msg: String) -> void` | EnemyWave, others | Development-error sink that survives release builds. Tests replace it. |
| `to_ticks(seconds: float) -> int` | Combat, EnemyWave, TowerSim, HeroSim, Flow, HudLogic | Rounds half away from zero; `dt` fixed at build. |
| `tap_slop`, `edge_reject_margin`, `reduce_motion`, field width, safe-area insets; Combat's counters, tower IDs and role tags, launch ID, build hash, AppRoot's retry latch | HudLogic | Injected by the wrapper (Battle HUD Rule 1). |
| `dt: float` | HudLogic | The fixed tick, for `intermission_left × dt` on Tower's bonus read. |

All are method Callables on objects `Battle` holds in typed fields, since the Builder holds nothing and a Callable does not keep its target alive (B4 rule, QQ-17). There is one StatAccessor per battle.

### B10. HUD read surface (ADR-0006, ADR-0010)

The HUD reads, never writes: HeroInput's `aim_state()`, `button_press()` and `cooldown_digit()`, read by HudField; `Flow.phase()`, `lives()`, `intermission_left`, `result()`; `TowerSim.gold()`, `early_call_bonus()`, `slows_applied()`, the `tower_built` signal; `TowerInput.chip_state()`; `HeroSim` queries and `cooldown_left`; `EnemyWave.wave_index()`, `got_through_by_type()`; `Combat.hero_share()` for the end-of-stage log. It also listens to TowerInput's `tower_inspected` signal. The cooldown total is Burst `cooldown`, read through the accessor with the injected `burst_id`; Hero exposes no total. All these reads now exist in their owners' GDDs. `burst_button_centre()` is owned by the HUD and read once by HeroInput at registration.

### What cannot be tested headless

These run only in the editor or on a device. ADR-0007 lists them as manual-evidence stories in `production/qa/evidence/`: the InputAdapter and Control event order; lifecycle notifications; `free()` vs `queue_free()` timing on retry; safe-area values; the catalogue load from an Android export; draw-call and frame-time budgets. Everything in B0 to B2 and B4 to B9 runs headless, including the weakref test, provided the test itself holds no reference to the old battle.

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

Eleven ADRs close all 120 gaps. Numbers are proposed, in dependency order, and `/architecture-decision` assigns the final ones. The review used labels P01 to P15; the column maps them. Version 1 proposed 15. To cut scope for a solo part-time developer (LP-FEASIBILITY 13), four pairs were folded: Fatal Path into App Lifecycle, Determinism into the Tick ADR, Combat API into the Enemy Entity ADR, and Dev Telemetry into the command and resolver ADRs. Input Resolver moved to Foundation to match its module. TR-hero-012 (bot equivalence) moved to ADR-0010 because it needs the command enums.

| Proposed ID | Title | Layer | Depends on | Review label | TRs | Engine risk |
|---|---|---|---|---|---|---|
| ADR-0001 | App Lifecycle, Composition Root and Fatal Path | Foundation | none | P01, P06 | 15 | HIGH |
| ADR-0002 | Catalogue Storage Format, Manifest and Validation | Foundation | ADR-0001 | P03 | 10 | HIGH |
| ADR-0003 | Input Adapter, Display Stretch and Platform Lifecycle | Foundation | ADR-0001 | P05 | 11 | HIGH |
| ADR-0004 | Fixed-Tick Clock, Tick Order, Frame Order and Determinism | Foundation | ADR-0001, ADR-0003 | P02, P07 | 20 | HIGH |
| ADR-0005 | Stat Accessor and Read-Context Contract | Foundation | ADR-0002, ADR-0001 | P04 | 6 | LOW |
| ADR-0006 | Battle Signal Contracts and View Allowlist | Foundation | ADR-0001, ADR-0004 | P10 | 10 | MEDIUM |
| ADR-0007 | Headless Test Harness, gdUnit4 and Layer Lint | Foundation | ADR-0001, ADR-0006 | P08 | 6 | MEDIUM |
| ADR-0008 | Input Resolver Core and Signal Contract | Foundation | ADR-0003, ADR-0006 | P09, part of P15 | 11 | MEDIUM |
| ADR-0009 | Enemy Entity, Roster and Combat API | Core | ADR-0001, ADR-0005 | P11, P12 | 16 | MEDIUM |
| ADR-0010 | Sim/Input Split, Command Result Codes and Dev Telemetry | Core | ADR-0004, ADR-0008, ADR-0009 | P13, part of P15 | 10 | LOW |
| ADR-0011 | Battle Field Rendering and Draw-Call Budget | Presentation | ADR-0009, ADR-0010 | P14 | 5 | MEDIUM |

### What each ADR decides and which requirements it covers

**ADR-0001 App Lifecycle, Composition Root and Fatal Path** (Foundation). Decides: no autoloads, AppRoot states (Boot, InStage, Fatal), scene-free builder, injected callables (method Callables only, no capturing lambdas or bind), per-battle FatalLatch, push_error vs assert, dev-error sink, retry by dropping references and the weakref proof, free() vs queue_free() timing. It records the settled answers on who cancels input and where the resolver is built (see Open Questions, Closed).
Covers (15): TR-data-004, TR-data-006, TR-data-009, TR-data-011, TR-input-012, TR-state-001, TR-state-002, TR-state-009, TR-state-011, TR-enemy-005, TR-enemy-012, TR-tower-006, TR-tower-013, TR-hero-004, TR-hud-006.

**ADR-0002 Catalogue Storage Format, Manifest and Validation** (Foundation). Decides: Resource vs JSON, record classes, strict field checks, manifest load proven on an Android export, read-only proof with duplicate_deep, content tests.
Covers (10): TR-data-001, TR-data-002, TR-data-003, TR-data-005, TR-data-007, TR-data-013, TR-data-015, TR-enemy-001, TR-hero-014, TR-hud-016.

**ADR-0003 Input Adapter, Display Stretch and Platform Lifecycle** (Foundation). Decides: engine event path and its order against _process and Controls (a spike first), touch and mouse emulation, 4.7 device IDs, safe area, stretch mode and aspect, minimum width, tall-phone behaviour, pause and focus notifications per platform; decided here, inherited later by the Mobile Platform GDD.
Covers (11): TR-input-002, TR-input-003, TR-input-004, TR-input-005, TR-input-006, TR-input-013, TR-input-016, TR-state-010, TR-hud-002, TR-hud-003, TR-hud-014.

**ADR-0004 Fixed-Tick Clock, Tick Order, Frame Order and Determinism** (Foundation). Decides: tick driver and rate, clamp value and max ticks per frame, the one tick order, commands between ticks, the in-sim clock gate, real-time presentation clocks, seeded RNG and cosmetic RNG split, float policy and per-architecture baselines, frame budget split.
Covers (20): TR-state-003, TR-state-004, TR-state-005, TR-state-006, TR-state-007, TR-state-012, TR-state-014, TR-combat-009, TR-combat-014, TR-enemy-002, TR-enemy-003, TR-enemy-007, TR-tower-005, TR-tower-010, TR-hero-003, TR-hero-006, TR-hero-011, TR-hero-013, TR-hud-005, TR-hud-007.

**ADR-0005 Stat Accessor and Read-Context Contract** (Foundation). Decides: stat_int and stat_float, ReadContext reuse per caller, key vocabulary and types, non-fatal lookups.
Covers (6): TR-data-008, TR-data-010, TR-enemy-006, TR-tower-003, TR-hero-005, TR-hud-011.

**ADR-0006 Battle Signal Contracts and View Allowlist** (Foundation). Decides: synchronous emit, commit before emit, final signal names (QQ-07) and payloads, ID types, view allowlist.
Covers (10): TR-data-014, TR-state-008, TR-combat-010, TR-enemy-004, TR-tower-004, TR-tower-012, TR-hero-008, TR-hud-004, TR-hud-010, TR-hud-012.

**ADR-0007 Headless Test Harness, gdUnit4 and Layer Lint** (Foundation). Decides: fixtures, recording fakes that assert payloads, listener-count test, push_error reporting, layer-import lint, the manual-evidence list for what cannot run headless, GDScript 4.7 pitfalls for the control manifest.
Covers (6): TR-data-012, TR-input-014, TR-state-013, TR-combat-012, TR-enemy-014, TR-tower-014.

**ADR-0008 Input Resolver Core and Signal Contract** (Foundation). Decides: pure resolver, hit-target registry, state machine, re-entrancy queue, payloads, gesture log.
Covers (11): TR-input-001, TR-input-007, TR-input-008, TR-input-009, TR-input-010, TR-input-011, TR-input-015, TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009.

**ADR-0009 Enemy Entity, Roster and Combat API** (Core). Decides: Targetable base class, Health and Status attachment, roster ownership and typed lists, path lookup, deliver guards, targeting helpers, per-tick budget.
Covers (16): TR-combat-001, TR-combat-002, TR-combat-003, TR-combat-004, TR-combat-005, TR-combat-006, TR-combat-007, TR-combat-008, TR-combat-013, TR-enemy-008, TR-enemy-009, TR-enemy-010, TR-enemy-011, TR-enemy-013, TR-tower-007, TR-hero-007.

**ADR-0010 Sim/Input Split, Command Result Codes and Dev Telemetry** (Core). Decides: HeroSim/TowerSim vs HeroInput/TowerInput, result enums with OK = 0, gold ownership, bot equivalence, run counters and run log.
Covers (10): TR-tower-001, TR-tower-002, TR-tower-008, TR-tower-009, TR-hero-001, TR-hero-002, TR-hero-009, TR-hero-012, TR-hero-015, TR-hud-013.

**ADR-0011 Battle Field Rendering and Draw-Call Budget** (Presentation). Decides: single _draw nodes, pools, draw order, path polygon, HUD draw budget, hit-flash shader question.
Covers (5): TR-combat-011, TR-enemy-015, TR-tower-015, TR-hud-001, TR-hud-015.

### Priority

**Must have before any code is written (Foundation, 8):** ADR-0001 to ADR-0008. ADR-0003 starts with a short verification spike on a device (event order, touch fields, lifecycle notifications, safe area), because ADR-0004 and ADR-0008 rely on what it finds. Treat that spike as real work, not paperwork.

**Must have before the named system's first story (Core, 2):** ADR-0009 before any Combat or Enemy & Wave story (the Combat GDD names the enemy object kind and Health/Status attachment as a prerequisite). ADR-0010 before any Hero or Tower story (HeroInput and TowerInput placement).

**Can defer (Presentation, 1):** ADR-0011, to the first phone build, when draw calls are first measured.

### Decisions made in this document that need no separate ADR

These follow directly from the GDDs and the gate reviews, and the ADRs above cite them: no autoloads; simulation classes extend `RefCounted`; presentation never feeds the sim; commands run between ticks; the tick gate lives inside `Battle.tick`; `Targetable` is a Core base class; result enums put `OK = 0` first; progression systems own their save schema; code root `src/` with one folder per layer.

## Architecture Principles

1. **The battle is a plain function of its inputs.** `(catalogue, stage_id, seed, command script)` determines the result. The sim runs headless, with no scene, no clock and no engine event. Bots, tests and the phone build run the same code. Everything else in this document follows from that.
2. **No globals, no autoloads.** The App Root holds the catalogue. The Builder injects it, plus `halted()`, `fatal()`, `targets()`, `cancel_input()`, the error sink and `to_ticks`, into whoever needs them. Dependency injection over singletons is a coding standard, and it is what makes each system unit-testable.
3. **Data drives gameplay, read at use time.** No gameplay number lives in code. Every value a modifier could ever touch goes through the one stat accessor and is never cached, so the Vertical Slice stat resolver drops in without call-site changes.
4. **Commit, then emit; observe, never steer.** State is final before any signal. Views and logs listen but cannot change a result, and a battle with all of them removed is identical.
5. **Fail loudly, once, and everywhere the same way.** No fallbacks in any build. One idempotent fatal path. Checks that matter in release use injected handlers and `push_error`, never `assert`, because exports strip it.
6. **Verify post-cutoff engine behaviour before building on it.** Touch input, stretch, lifecycle, safe area and Control event order are unverified in the pinned reference. The ADR that depends on one verifies it against live 4.7 docs or a device first, then records the result in the engine reference.

## Open Questions

| ID | Question | Priority | Resolved by |
|---|---|---|---|
| QQ-01 | Tick driver: custom accumulator in `_process` or `_physics_process`; tick rate (60 Hz proposed); `MAX_TICKS_PER_FRAME`; behaviour on a frame stall. | High | ADR-0004 |
| QQ-02 | Stretch mode and aspect (`project.godot` sets none; 4.7 changed new-project defaults), minimum width (360 dp proposed), whether a taller phone letterboxes or reveals the off-field entry. Layout rules L3, L5 to L7 depend on the answer. ADR-0003 decides; the Mobile Platform GDD inherits. | High | ADR-0003 |
| QQ-03 | Catalogue format: typed `Resource` or JSON; how missing fields and fractional integers are caught; how read-only is enforced and snapshot-tested (`duplicate_deep()`); proof it loads from an Android export. | High | ADR-0002 |
| QQ-04 | Type of `tower_id` and other IDs across signals: `StringName`, `String` or `int`. | Medium | ADR-0006 |
| QQ-05 | `Vector2` is documented as 32-bit in a stock build but unverified on 4.7. PinGeometry avoids `Vector2` methods until it is. Float results may differ between x86 and ARM, so bot baselines are kept per architecture. | Medium | ADR-0004 |
| QQ-06 | Engine event order: does input arrive before `_process`; Control event order against `_unhandled_input`; which notifications fire on Android and iOS for pause and focus loss; moves and releases delivered after a `cancel` on focus return. | High | ADR-0003 (spike) |
| QQ-07 | Signal names that still break the past-tense naming rule: `tap`, `ground_tap`, `pressed`, `idle` (Input GDD) and `waves_complete` (Enemy & Wave GDD). `phase` is already renamed `phase_changed`, in the GDDs too. Rename (for example `tapped`, `ground_tapped`, `became_idle`, `waves_completed`) or record an exception, before ADR-0008 and before any test uses them, and update the GDDs to match. | Medium | ADR-0006, ADR-0008 |
| QQ-08 | Technical-director acceptance of four changes the GDDs make to earlier notes: composition root as a scene-free builder; ProjectileSpawner cut; the one tick order; path and slots moved from the stage scene to the Stage record. The TD-ARCHITECTURE review judged all four sound on technical merit; acceptance is recorded only when the ADRs are Accepted, on the user's confirmation. | High | ADR-0001, ADR-0004, ADR-0009 |
| QQ-10 | Art bible §8 budgets a hit-flash shader; the Combat GDD uses none. | Low | technical-artist, ADR-0011 |
| QQ-11 | Unmeasured budgets: the frame split in Data Flow 10, 60 draw calls, 256 MB, about 400 range checks under 2 ms per tick, catalogue load at most 1000 ms median on an Adreno 5xx-class device. All need a device run at the first phone build. | Medium | ADR-0004, ADR-0011, performance-analyst |
| QQ-12 | No Mobile Platform & Performance GDD yet. A large top inset collides the HUD band with the arc's top panel and prompt. | Medium | Mobile Platform GDD |
| QQ-13 | `tests/README.md` is stale: gdUnit4 is now in `addons/` and the class cache is tracked in git. Whether the CI test command needs a prior `--import` step on a fresh clone. | Low | ADR-0007, `/test-setup` |
| QQ-14 | Stage tooling: a converter or editor for point-list stages before about 20 stages exist. | Low | tools-programmer, after MVP |
| QQ-15 | GDScript 4.7 pitfalls have no rule yet: a typed-method override needs an explicit `return`; packed-array element writes skip setters; lambdas capture locals by value; signal parameter types are not checked at `emit()`. Turn them into Required and Forbidden rules. | Medium | ADR-0007, `/create-control-manifest` |
| QQ-16 | Every `class_name` is global. Short names (`Flow`, `Combat`, `Battle`, `Catalogue`, `Clock`) risk collisions with engine or addon classes. Prefix them or lint for collisions. | Low | ADR-0007 |
| QQ-17 | Method `Callable`s and signal connections did not keep a `RefCounted` alive in a 4.7.2 editor probe, and `.call()` on a dead or empty one raised a script error and aborted the calling function. So every target needs a strong holder (Flow review, 2026-11-04). Re-confirm on an export template. | Medium | ADR-0001 |
| QQ-18 | Flow's command method names and their result enums (`start_wave`, `call_early`, `StartResult`, `CallResult`) are proposed here; the Game State GDD names the actions but not the methods. | Low | ADR-0010 |

**Closed 2026-11-03 (the ADR records these, it does not reopen them):**
- **QQ-17 (lifetime half):** `Battle` strongly holds every helper, and `cancel_input()` is a guarded public method (Flow Rules 2a, 15). Repeating the probe on an export build stays with ADR-0001.
- **QQ-09:** Reduce Motion is the `reduce_motion` flag on the Input record until Settings exists (Data GDD).
- **QQ-19:** Flow cancels through the injected `cancel_input()` on Won, Lost, Paused and Fatal; AppRoot cancels on retry; the adapter cancels on lifecycle events. A second call finds Idle and does nothing (Input Rule 7, criterion 16).
- **QQ-20:** the catalogue validator rejects `tap_slop` ≤ `drag_slop` at load, the existing Fatal route (Data Rule 7). The wrapper builds the resolver, matching Input Rule 11 and Flow Rule 2; a null from `create` there calls the failure handler (Flow Rule 18).
