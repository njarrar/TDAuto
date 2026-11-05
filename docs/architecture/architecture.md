# TowerRiot: Master Architecture

## Document Status
- Version: 3 (brought up to date with ADR-0001 to ADR-0011 after `/architecture-review` 2026-11-05)
- Last Updated: 2026-11-05
- Engine: Godot 4.7.2 (GDScript, Mobile renderer, Godot Physics 2D). Pinned in `docs/engine-reference/godot/VERSION.md`.
- GDDs Covered (8 MVP systems): `data-config-pipeline`, `input-gesture-resolver`, `game-state-stage-flow`, `combat-damage`, `enemy-wave`, `tower-system`, `hero-system`, `battle-hud`. Context only: `game-concept`, `systems-index`.
- Vertical Slice and Alpha systems (14 of 22) have no GDD yet. They appear in the layer map as reserved slots with the seams MVP code must leave for them. This document is revised when those GDDs exist.
- ADRs Referenced: ADR-0001 to ADR-0011 exist, all **Proposed**, none Accepted (plus the companion `adr-0007-lint-rules.md`). All eleven were amended 2026-11-05 after `/architecture-review` (cycle cut, nine minor conflicts, Required ADRs item 2). ADR-0012 "Renderer and First Target Device" is planned (Required ADRs). Where a section below and an ADR disagree, the ADR wins; "ADR-pending" in older text now means "decided by the named ADR, still Proposed".
- Technical Requirements: 158, all registered in `docs/architecture/tr-registry.yaml` (120 before 2026-11-05, 38 added by that review). Coverage at the 2026-11-05 review: 0 Accepted, 145 Proposed, 11 partial, 2 gaps. The 2026-11-05 amendments address 9 of the 11 partials in text (TR-data-003 and TR-data-015 wait for ADR-0012; TR-input-005 waits for spike SP5); the next `/architecture-review` recounts.
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
5. Combat (Core) cannot name the enemy class (Feature) without an upward dependency. Combat therefore owns a small base class, `Targetable extends RefCounted` (`spawn_id`, `distance`, `pos_x`, `pos_y`, `removed`, `health`, `status`; sim positions are float scalars, ADR-0009), and Enemy & Wave's `Enemy` extends it. Combat's helpers take and return `Targetable`, so every field access is checked at parse time rather than by dynamic lookup on `Object`. Lists are built as `Array[Targetable]` from the start, because GDScript typed arrays are invariant and an `Array[Enemy]` cannot be passed where `Array[Targetable]` is expected. ADR-0009 ratifies this.
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
| 21 | Settings & Accessibility | Alpha | Presentation | Owns Reduce Motion. Until it exists the value is the Input record's `reduce_motion` field, read by AppRoot (ADR-0001 Decision 8, QQ-09 closed) |
| 22 | Cross-Tree Synergies (full) | Alpha | Feature | Reserved |

Note on requirement tags: the `Layer` column in `requirements-traceability.md` tags each *requirement* by the kind of work it asks for. It does not override the system layer above. Enemy & Wave, Tower and Hero requirements are tagged Core there because they run inside the tick; their module layer is Feature, as in the systems index.

### Seams MVP code must leave for later tiers

| Later system | Seam MVP code must keep |
|---|---|
| Stat & Modifier Resolution (VS) | Every modifiable value is read through the one stat accessor at use time, never cached (TR-data-008). The resolver replaces the accessor's internals with no call-site change. Modifier source tags are reserved now. |
| Save/Load (VS) | Progression systems expose `to_dict()` / `from_dict()` with a version field and never call Save. MVP has nothing to save, so no save code is written, but no MVP system may hold progression state in a global. |
| Stage Progression (VS) | Flow keeps its result (outcome, last wave started, lives left, Combat per-source damage) readable after the outcome (TR-state-006, TR-combat-005). |
| Skill Tree / Hero Weapons (VS) | Hero and Tower read stats through the accessor with a read context holding `def_id`, so a tree node changes a stat without touching Hero or Tower code. |
| Settings (Alpha) | Reduce Motion is read by views from one place: AppRoot reads the Input record's `reduce_motion` and passes it to `wrapper.attach`; Settings later changes only AppRoot's source (ADR-0001 Decision 8). |

## Module Ownership

Naming follows `project.yaml`: classes PascalCase, files snake_case, signals past tense. No signal is an exception; ADR-0006 renamed the five that broke the rule (QQ-07).

Code root is `src/` (Godot). Proposed folders, one per layer: `src/foundation/`, `src/core/`, `src/feature/`, `src/presentation/`, `src/root/`. Tests mirror them under `tests/unit/` and `tests/integration/`.

### Foundation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **Catalogue** (Data & Config) | The Ready catalogue: typed read-only records (Tower, Enemy, Wave, Stage, Hero, Burst, Input). The manifest. Load state (Unloaded, Loading, Ready, Failed). | `load(manifest) -> LoadResult`; typed record lookup by ID; `is_tower(id)`, `level_count(def_id)` (non-fatal) | Data files via manifest | JSON data files and a JSON manifest read with `FileAccess` and `JSON`, built into typed read-only `RefCounted` records; never `ResourceLoader` (MEDIUM; ADR-0002 Decisions 1, 5). Read-only proof is a canonical `to_dict()` snapshot, not `duplicate_deep()` (ADR-0002 Decision 7) |
| **Validator** (inside Data & Config) | Error list `{code, source, record_id, field}`. Tiered checks. | `validate(records) -> Array[ValidationError]` | Catalogue records | None (plain GDScript) |
| **StatAccessor** (Data & Config) | Stat-key vocabulary and int/float type per key. Nothing else; no stored values. | `stat_int(ctx, key) -> int`, `stat_float(ctx, key) -> float`; a type mismatch or bad call goes to the injected failure handler | Catalogue; later Stat & Modifier | None |
| **InputResolver** | Hit-target registry, the four-state machine, the FIFO re-entrancy queue, the frozen winners of the current press. No clock, no scene. | `press`, `move`, `release`, `cancel_pointer`, `cancel`; `register`, `unregister`, `set_centre`, `set_enabled`; signals `pressed`, `tapped`, `ground_tapped`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `became_idle` (payloads in B2, names ADR-0006) | `drag_slop`, `tap_slop` from the Input record and the battle's `dev_error`, passed to `create()` by the Builder; stored as `Battle.resolver` (ADR-0008) | None |
| **InputAdapter** (the only engine-facing input code) | Translation of engine events to the five resolver calls; edge and safe-area rejection; touch/mouse de-duplication; lifecycle `cancel()` calls | `lifecycle_paused` (pause) for Flow and the HUD; `display_changed` and `field_insets()` for the HUD; `flush()` for the wrapper's frame step 0; `cancel_all()` as the Battle input canceller (ADR-0003) | Godot input events, `DisplayServer`, viewport | `InputEventScreenTouch`, `InputEventScreenDrag` and the `canceled` flag (**HIGH, NEEDS VERIFICATION**); `_unhandled_input` vs `Control` ordering (**HIGH**); `Node.PROCESS_MODE_ALWAYS` (LOW); `DisplayServer.get_display_safe_area()` (**HIGH**); `Viewport.size_changed` (LOW); app lifecycle notifications (**HIGH**); mouse device ID change (4.7, **HIGH**) |
| **FatalLatch** | One per battle plus one on AppRoot. Pure: keeps the first cause, idempotent, `is_fatal()`. No screen, no scene, no catalogue. | `fatal(cause)` (injected as a `Callable`), `is_fatal()` | Nothing | `push_error` (LOW). `assert` is never used for release-relevant checks (stripped in exports) |
| *Mobile Platform (VS)* | Safe-area mapping, export presets, effect pooling, particle caps | Reserved | | `DisplayServer` (HIGH) |
| *Save/Load (VS)* | Save file, version field, migration | Reserved | | `FileAccess` (MEDIUM) |

### Core

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **Flow** (Game State, pure object) | Stage state machine (Build, Wave, Intermission, Paused, Won, Lost, Fatal). Lives. `intermission_left` as integer ticks. The stage result. The remembered phase while Paused. | `phase()`, `lives()`, `result()`, `in_build()`, `intermission_left`; commands `start_wave()`, `call_early()`, `pause()`, `resume()` (names proposed, QQ-18); signals `phase_changed`, `lives_changed`, `wave_called_early` | Enemy & Wave signals (`wave_cleared`, `waves_completed`, `enemy_leaked`); injected `cancel_input()`, `wave_index`, `dealt_by_kind`, `dealt_total` and the battle FatalLatch; the adapter's lifecycle signal (wired by the Builder's wrapper step) | None |
| **Combat** | `Targetable` base class, `DamageEvent` value, `Health` and `Status` classes (one each per target, held one way by the Targetable, created by `attach`), per-source damage counters. | `attach(t, max_hp) -> bool`; `deliver(event) -> float`; `apply_slow`; `speed_factor`; `tick_status(roster)`; `first_in`, `nearest_in`, `all_in_radius` (float scalar origins); `dealt_by_id`, `dealt_by_kind`, `dealt_total`, `hero_share`; `is_dead`, `hp_left`; `report_attack`; signals `attack_fired`, `damage_applied` | Values passed in by callers; `to_ticks` injected at build (it carries the fixed `dt`; Combat takes no separate `dt`, ADR-0009) | None (pure) |
| *Stat & Modifier (VS)* | Modifier stack, fixed evaluation order | Behind `StatAccessor` | Catalogue, tree nodes | None |

### Feature

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **EnemyWave** | Roster (sole owner of enemies), per-enemy `ReadContext`s keyed by `spawn_id`, wave state machine (`WaveState`), `PathTrack` (cached cumulative lengths), `spawn_id` counter | `roster()`, `targets()` (both in `spawn_id` order, internal buffers, read-only, valid for the slot only); `advance()`, `reap()`, `start_next_wave()`, `add_enemy(def_id, start_distance)` (EnemyWave and tests only); signals `enemy_leaked(lives_cost)`, `enemy_killed(bounty)`, `wave_cleared(intermission_duration)`, `waves_completed` | Stage and Wave records (direct), stats via accessor, `Combat.attach`, `dt`, `FieldBounds` size, injected `halted()`, `fatal`, error sink and `to_ticks` | None in the sim. Views use `CanvasItem._draw` (see Presentation) |
| **TowerSim** | Gold (non-negative int), slots, towers, per-tower `cooldown_left` (ticks), `slows_applied` | `build(slot_index, tower_id) -> BuildResult`, `upgrade(slot_index) -> UpgradeResult`, `tick()`, `gold()`, `slot_count()`, `slot_tower(i)`, `slot_level(i)`, `slot_cooldown_left(i)`, `slot_position(i)`, `slows_applied()`, `state_fields()`; signals `gold_changed`, `tower_built`, `tower_upgraded` (ADR-0010) | `slot_positions`, `starting_gold`, `early_call_seconds_per_gold` from the Stage record; accessor; `enemy_killed` straight from EnemyWave and `wave_called_early` from Flow (both wired by the Builder); injected `targets()`, `halted()`, `between_ticks()`; Combat helpers | None |
| **HeroSim** | Hero position, pin target, pin state, burst state, cooldown, telegraph, run counters | `pin(pos) -> PinResult`, `burst(aim_point) -> BurstResult`, `tick()`, read-only queries (`position`, `pin_target`, `pin_state`, `burst_state`, `cooldown_left`, `hero_id`, `burst_id`, `state_fields`), counters (ADR-0010 Decision 7); signals `hero_pinned`, `burst_started` | Stage record (`hero_start`, `pin_rect`, `pin_exclusion`), accessor, Combat, injected `targets()`, `halted()`, `between_ticks()`, `in_build()` and `left_handed` | None |
| **PinGeometry** | Pure clamp and validity maths in float scalars | `is_valid(pos) -> PinResult` (`OUT_OF_BOUNDS`, `BUTTON_ZONE` or `OK`, per Hero Rule 14), `clamp(pos)` | Pin rect and exclusion segments | None (avoids `Vector2` methods on purpose, see QQ-05) |
| *Stage Progression, Skill Points, Skill Tree, Hero Weapons, Synergies (VS/Alpha)* | Reserved | | | |

### Presentation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **HudLogic** | HUD presentation state (button arm model, arc state, snapshot). No gameplay state. | `advance(ms)`, view-model reads | Flow, TowerSim, HeroSim, EnemyWave, Combat (read-only), accessor for costs | None |
| **HudTopBand** | Display-only `Control`s that ignore input | None | HudLogic | `Control`, `mouse_filter` (HIGH, 4.6 dual focus) |
| **HudField** | One `_draw` (`Node2D`) for HUD field art; hit targets are resolver discs | None | HudLogic, resolver registry | `CanvasItem._draw` (MEDIUM, 4.7 line feather; `LINE_BIAS`, ADR-0011 Decision 6) |
| **ResultScreen, PausedScreen** | Full-screen modal `Control`s | Retry, Resume requests | Result snapshot | `Control` input consumption before the adapter (**HIGH, NEEDS VERIFICATION**) |
| **HeroInput** (`RefCounted`, built in `attach`) | Aim state machine (Idle, Cancelling, Live), aim-point re-clamp, cancel hysteresis | `update()`, `aim_state()`, `aim_point()`, `cooldown_digit()` | Resolver signals, HeroSim queries, accessor (`REACH`), injected `halted()` and `in_build()`, `burst_button_centre` value from the HUD | None |
| **TowerInput** (`RefCounted`, built in `attach`) | Slot, tower and chip discs, `ChipWindow` | `slot_tapped`, `tower_inspected`, `chip_state()`, `is_chip_open()`, `advance(ms)` | Resolver, TowerSim reads and `tower_built`, accessor (`level_count`), Flow `phase_changed`, injected `halted()` | None |
| **ChipWindow** | Real-time upgrade-chip timing (200 and 1500 ms consts) | `advance(ms)`, `can_commit()` | Fed by TowerInput each frame | None |
| **Field views** (FieldBackdrop, TowerView, EnemyView, CombatView, HeroView, each a drawer plus a `RefCounted` model) | Buffer pools (enemies 48 growing with a dev error, flash markers 16, tracers 64, death discs 48, glow 8), fixed sibling draw order on one canvas, the baked path strip (ADR-0011) | None | `roster()`, TowerSim per-slot reads (ADR-0010), Combat reads, P7 to P9, `Battle.stage_record`, `Battle.visual_keys` | `CanvasItem._draw` (MEDIUM; batching, counters and line look NEEDS VERIFICATION, ADR-0011 V1 to V4). Path corners are a baked mitred quad strip; its geometry rule is Stage validation (ADR-0002) |
| **RunLog / GestureLog** (dev only) | JSONL records in `user://run_log.jsonl` and `user://gesture_log.jsonl` | Injectable sink (`JsonlFileSink.write_line`); `DevLogs` session object on AppRoot | View signals P1, P4, P6, P7; HudLogic's `snapshot_taken` and `call_made` Callables | `FileAccess` append (MEDIUM; check the `bool` return). Decided in ADR-0010 and ADR-0008 |

### Composition Root

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **AppRoot** (main scene, no autoload) | App states Boot, InStage, Fatal (Game State GDD). The Ready catalogue for the session. The app-level FatalLatch. The retry latch. Reads `reduce_motion` from the Input record for `wrapper.attach` (ADR-0001 Decision 8). | Starts the catalogue load; builds battles and drops them | Catalogue, FatalLatch | `Node`, `PackedScene`, `Object.free()` vs `queue_free()` timing for the wrapper on retry (**MEDIUM, NEEDS VERIFICATION**), `weakref()` (LOW) |
| **Builder** (`build(catalogue, stage_id, rng_seed, fatal_handler)`) | Nothing persistent. Creates the per-battle FatalLatch first, then constructs one `Battle` and makes every connection. | Returns a `Battle` | Every sim module | `Signal.connect(Callable)` (LOW). No `CONNECT_DEFERRED` on gameplay signals (TR-enemy-004). Injected callables are method Callables only: no lambda or `bind()` that captures a sim object (TD-ARCHITECTURE B4; Callable reference semantics **NEEDS VERIFICATION**, QQ-17) |
| **BattleWrapper** (scene) | The `BattleClock` (pure accumulator, clamp, stall rule, backlog dropped on entering and leaving `PAUSED`) and the frame order (ADR-0004 Decision 5). Also the input adapter, views and the HUD. Absent headless. | None | Battle, adapter | `Node._process` (LOW, frame timing NEEDS VERIFICATION, ADR-0004 V1 to V3); no `_physics_process` (ADR-0004) |
| **Fatal screen** (scene) | Catalogue-free, guaranteed to load. Shown by AppRoot. | None | AppRoot FatalLatch cause (development builds show it) | `PackedScene` (LOW) |

### Dependency diagram (MVP)

```
                          ┌──────────── AppRoot ────────────┐
                          │ owns Catalogue, FatalLatch      │
                          └──────────────┬──────────────────┘
                                         │ build(catalogue, stage, rng_seed, fatal)
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
Engine delivers input events (between frames expected; ADR-0003 SP1). InputAdapter queues the five calls
  InputAdapter ──► InputResolver ──► signals ──► HeroInput / TowerInput / HudLogic
                                                    │ commands: pin, burst, build, upgrade,
                                                    │ start_wave, call_early  (run NOW, between ticks)
BattleWrapper._process(delta):
  0. adapter.flush(): queued calls reach the resolver; gesture signals and commands run now (ADR-0003)
  1. Advance real-time models:  HudLogic.advance(ms), TowerInput.advance(ms) (feeds ChipWindow)
  2. Clock: n = BattleClock.advance(delta)   (ADR-0004: 60 Hz, accumulator phased at 0.5 dt,
     MAX_TICKS_PER_FRAME = 3 provisional, carry capped at 1.5 dt, a frame over 0.5 s runs 0 ticks,
     accumulator reset on entering and leaving PAUSED)
  3. n times:  battle.tick(battle.sim_time.dt)
       Battle.tick itself returns at once unless Flow.phase() is WAVE or INTERMISSION
       and halted() is false. The gate lives in the sim, so it holds headless too.
  4. HeroInput.update() (hit-disc centre, aim point and digit from post-tick state, so they match
     the drawn frame; ADR-0004 Decision 5), then refresh views from read-only queries
     (each view model's refresh(view_ms), then queue_redraw() on changed drawers; ADR-0011 Decision 2)
```

| Data | Producer | Consumer | Kind |
|---|---|---|---|
| Touch/mouse events | Godot | InputAdapter | Engine callback |
| Five resolver calls | InputAdapter | InputResolver | Queued during event delivery; synchronous calls from `flush()` at frame step 0 (ADR-0003) |
| Gesture signals | InputResolver | HeroInput, TowerInput, HudLogic | Signal (synchronous) |
| Commands | HeroInput, TowerInput, HudLogic, bots | HeroSim, TowerSim, Flow | Synchronous call, **only between ticks**, returns a result enum |
| `tick(dt)` | BattleClock (BattleWrapper) | Battle | Synchronous call; gated inside Battle; `dt` must equal `battle.sim_time.dt` (ADR-0004) |
| View reads | Views | Sim modules | Read-only query |

Rule: commands run from `adapter.flush()` at frame step 0, before the frame's ticks, so the bonus the HUD shows equals the bonus paid (TR-hud-005). The queue makes the order independent of when the engine delivers events; ADR-0003 SP1 measures that timing (latency only) and SP11 the release-before-focus-loss case; ADR-0004 owns the frame order (Decision 5). `MAX_TICKS_PER_FRAME` is 3, provisional until ADR-0004 V6 (after acceptance) measures the whole tick on the device and sets it in the range 2 to 4. `BattleWrapper._process` is the only per-frame code in the battle subtree.

### 2. Simulation tick path

`battle.tick(dt)` runs these steps in this order, every tick, Intermission included (Build runs no ticks). The order is stated once, here and in ADR-0004 Decision 4 (Proposed); the four GDDs that restate it (Game State Rule 5, Combat Rule 11, Enemy & Wave Rule 12, Tower Rule 9) cite it.

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
| `waves_completed` | EnemyWave | Flow | Same |
| `lives_changed(current)`, `phase_changed(value)`, `wave_called_early(seconds_left)` | Flow | HudLogic (both), TowerSim (`wave_called_early`, W5), TowerInput (`phase_changed` for the chip), BattleWrapper (resets the accumulator to half a tick on entering and leaving PAUSED, ADR-0004 Decision 2), RunLog (development builds) | `phase_changed`, not `phase`, because a member and a signal cannot share a name and Flow also needs a `phase()` read (TD-ARCHITECTURE B1; GDDs renamed by ADR-0006) |
| `gold_changed`, `tower_built`, `tower_upgraded` | TowerSim | HudLogic (`gold_changed`); TowerInput and RunLog (`tower_built`); GestureLog (`tower_upgraded`, development builds). Tower views poll (ADR-0011 Decision 3) | Commit first, `gold_changed` then the tower signal; a refusal emits nothing (ADR-0006 P3 to P5) |
| `hero_pinned`, `burst_started` | HeroSim | RunLog (`hero_pinned`; HeroView polls); CombatViewModel, HudLogic and RunLog (`burst_started`) | After state set; handlers never issue commands (ADR-0006 P6, P7) |
| `attack_fired`, `damage_applied` | Combat | Combat view, audio (Alpha) | View-only; listeners never call `deliver` or the accessor; `damage_applied` carries `source_kind` and `source_id`, never the `DamageEvent` (ADR-0006) |
| Gesture signals (`pressed`, `tapped`, `ground_tapped`, `drag_*`, `became_idle`) | InputResolver | HeroInput, TowerInput, HudLogic | Re-entrant calls queue FIFO and drain in the outermost call; `drag_cancelled` and `became_idle` can fire inside a tick, so their listeners never issue commands |

Rules for all of them (ADR-0006):
1. **Commit, then emit.** State is final before the first listener runs.
2. **Gameplay does not depend on listeners.** A battle with every view listener removed produces identical state (TR-tower-012, TR-hud-004).
3. **Wiring signals** (`enemy_leaked`, `enemy_killed`, `wave_cleared`, `waves_completed`, `wave_called_early`: the ones the sim itself consumes) are connected only in the Builder; every other battle signal is connected only in `BattleWrapper.attach` and disconnected in `detach`. No connection is deferred or takes any flag (ADR-0006 Decision 2).
4. **View allowlist.** A test fails if any battle signal has no listener, except signals on a named allowlist (TR-state-013).
5. Signals declare typed parameters, but GDScript does not check them at `emit()`, and a `connect` with a mismatched Callable fails only at runtime. The real guard is the listener-count test plus recording fakes that assert payloads and their types, not only call counts (ADR-0007). Catalogue IDs in payloads are `StringName`; slot, spawn and resolver ids are `int`; no payload carries a sim object (ADR-0006 Decision 4, QQ-04). Whether `emit()` checks types is ADR-0006 V1.

### 4. Initialisation order

```
Engine starts main scene ──► AppRoot._ready
  1. AppRoot FatalLatch ready; the catalogue-free fatal scene is loadable. AppRoot state: Boot
  2. Catalogue.load_manifest(path)   Unloaded ─► Loading ─► Ready | Failed
       Failed ─► fatal screen (no fallbacks, no save access)
  3. (VS) Save/Load boot: inject loaded progression into progression systems
  4. AppRoot holds Ready catalogue, picks stage_id and seed. AppRoot state: InStage
  5. Builder.build(catalogue, stage_id, rng_seed, fatal_handler)
       a. Create the per-battle FatalLatch first, so a fatal during build has somewhere to land,
          then the FatalRelay and the per-battle StatAccessor(catalogue, relay.fatal) (ADR-0005)
       b. Validate stage inputs; InputResolver.create(drag_slop, tap_slop) (null on bad slops: fatal)
       c. Construct Flow, Combat, EnemyWave, TowerSim, HeroSim
       d. Make every signal connection; inject halted(), in_build(), targets(), cancel_input(),
          left_handed, to_ticks and the error sink (method Callables only, no capturing lambdas)
       e. Return Battle (headless-safe: no node touched)
  6. BattleWrapper adds InputAdapter, Clock, HUD and field views around the Battle
  7. Flow enters Build
```

Dependency note: the stat accessor cannot be used before step 2 finishes. The resolver reads its slops directly from the Input record, not through the accessor (TR-input-012).

### 5. Retry and teardown path

```
Result screen "Retry" tapped (modal screen tap, not a Button; ADR-0003 Decision 8)
  ─► sets idempotent retry latch on AppRoot (does NOT free the caller)
AppRoot next frame:
  1. If Fatal: show fatal screen, stop
  2. Stop Clock;  battle.cancel_input() (adapter.cancel_all, which calls resolver.cancel(); ADR-0003 Decision 9)
  3. Free the wrapper and its nodes (adapter, HUD, views). Drop every reference to the Battle and the
     resolver: they are RefCounted, so they cannot be freed, only released. A weakref to the old
     Battle must then read null (TR-state-009, TR-enemy-008, TR-tower-013). That holds only if no
     reference cycle exists: no lambda or bind() capturing a sim object, no sim back-reference to Battle.
  4. Builder.build(...) again with the SAME catalogue (it is held by AppRoot)
```
Retry resets nothing in place. It rebuilds. Settled by ADR-0001 Decision 7: `detach()`, `remove_child()`, `queue_free()`, never `free()`; the battle is released when references drop, not when nodes are deleted. ADR-0001 V1 (2026-11-04) recorded that a method Callable holds only an ID (QQ-17); V2, the deletion timing, is still open before acceptance.

### 6. Pause and focus path

```
App loses focus / backgrounds / Android back  (APPLICATION_FOCUS_OUT, APPLICATION_PAUSED, WM_WINDOW_FOCUS_OUT, WM_GO_BACK_REQUEST; ADR-0003 Decision 6, SP10)
  InputAdapter ─► cancel_all() (empty queue, clear forwarded set, resolver.cancel())  then emits lifecycle_paused()
  Flow: remember phase, enter PAUSED, call the injected cancel_input(), emit phase_changed(PAUSED)
  Battle.tick now returns at once (the in-sim gate); BattleWrapper resets its accumulator to half a tick
  A finger held across the pause stays dead until lifted; the resume tap reaches nothing beneath
  Resume: Flow restores the remembered phase;  walk and telegraph resume exactly (TR-hero-013)
```
Real-time models (button arming, chip window) freeze while Paused (TR-hud-007).

### 7. Fatal path

```
Any of: catalogue load failure · bad accessor call · broken stage scene · bad stage input
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

Development builds only. `GestureLog` (created by the wrapper only when `OS.is_debug_build()`, ADR-0008 Decision 8) listens to `pressed`, `became_idle` and `tower_upgraded`, reads the resolver's `last_gesture()` copy and writes `user://gesture_log.jsonl`; `RunLog` listens to view signals P1, P4, P6, P7, receives HudLogic's snapshot and call records, and appends to `user://run_log.jsonl`. Both write through `JsonlFileSink` instances held by AppRoot's `DevLogs`, created only when `OS.is_debug_build()`. A write failure is one `dev_error`, never fatal, and release builds never write (TR-hud-013, TR-input-015; ADR-0010 Decision 10). Both listen only; neither can change a result.

### 10. Frame budget (proposal, unmeasured)

`project.yaml` sets 60 fps (16.6 ms), 60 draw calls and 256 MB, with a 30 fps floor on low-end Android. This split is a starting proposal; ADR-0004 Decision 10 confirms it with `MAX_TICKS_PER_FRAME = 3`, so one worst-case tick must fit 1.33 ms, and ADR-0011 owns draw calls. Both are confirmed on a device at the first phone build (QQ-11, ADR-0004 V6).

| Slice | Budget at 60 fps | Notes |
|---|---|---|
| Input, resolver, commands | 0.5 ms | Event count is small (one finger) |
| Simulation ticks | 4.0 ms total | Normal frame: one tick. At the catch-up clamp, `MAX_TICKS_PER_FRAME` (3, working default) ticks must fit here, 1.33 ms each; ADR-0004 V6 sets the final clamp (2 to 4) from the measured whole-tick p99. Combat's worst case (about 400 range checks per tick) is estimated under 2 ms per tick, unmeasured |
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
| Record classes: `TowerRecord`, `EnemyRecord`, `WaveRecord`, `StageRecord`, `HeroRecord`, `BurstRecord`, `InputRecord` | `Resource` or `RefCounted` (format is ADR-0002) | `src/foundation/data/records/` | `id: StringName` plus each GDD's fields. `StageRecord` holds `path_points`, `slot_positions`, `path_width`, `requires_bend`, `early_call_seconds_per_gold`, `hero_start`, `pin_rect`, `pin_exclusion`, `scene_ref`. `InputRecord` holds `drag_slop`, `tap_slop`, `edge_reject_margin`, `left_handed` | ADR-0002 |
| `ReadContext` | `RefCounted` | `src/foundation/data/read_context.gd` | `def_id: StringName`, `level: int = 0`, `live_entity: Object = null`. **One reused instance per caller** (per enemy, per tower slot, one for the hero), never one per read, so a tick allocates nothing | ADR-0005 |
| `Targetable` | `RefCounted` | `src/core/combat/targetable.gd` | `spawn_id: int`, `distance: float`, `pos_x: float`, `pos_y: float` (cached once per tick; float scalars, not `Vector2`, QQ-05), `removed: bool`, `health: Health`, `status: Status`; `view_position() -> Vector2` for views and view-signal payloads only | ADR-0009 |
| `Enemy` | `Targetable` | `src/feature/enemy_wave/enemy.gd` | Adds `def_id: StringName`, `segment: int` (path segment hint); `_init` calls `super(spawn_id)`. Its `ReadContext` is held by EnemyWave keyed by `spawn_id`, never by the enemy (ADR-0005, no cycle) | ADR-0009 |
| `Health` | `RefCounted` | `src/core/combat/health.gd` | `hp: float`, `max_hp: float` (the spawn seed). Holds no reference | ADR-0009 |
| `Status` | `RefCounted` | `src/core/combat/status.gd` | `strength: float`, `ticks_left: int`. Holds no reference | ADR-0009 |
| `PathTrack` | `RefCounted` | `src/feature/enemy_wave/path_track.gd` | `static make(path_points) -> PathTrack` (null on unusable points); cumulative lengths; `place(e: Enemy)` | ADR-0009 |
| `FieldBounds` | `RefCounted` (constants only) | `src/foundation/field_bounds.gd` | `WIDTH := 540.0`, `HEIGHT := 960.0`; injected into EnemyWave by the Builder | ADR-0009 (ADR-0003 uses it for the field size and does not take ownership) |
| `DamageEvent` | `RefCounted` | `src/core/combat/damage_event.gd` | `target: Targetable`, `amount: float`, `source_kind: Combat.SourceKind`, `source_id: StringName` | ADR-0009 |
| `StageResult` | `RefCounted` | `src/core/flow/stage_result.gd` | `outcome: Flow.Phase` (WON, LOST or FATAL), `last_wave_started: int`, `lives_left: int`, `dealt_tower`, `dealt_hero`, `dealt_burst`, `dealt_total: float` copied from Combat. Built once by Flow at the outcome commit, before `phase_changed`; holds no reference | ADR-0006 |
| `Battle` | `RefCounted` | `src/root/battle.gd` | Read-only members: `flow: Flow`, `combat: Combat`, `enemy_wave: EnemyWave`, `tower_sim: TowerSim`, `hero_sim: HeroSim`, `fatal_latch: FatalLatch`, `stat_accessor: StatAccessor` (ADR-0005), `input_record: InputRecord` (ADR-0003), `resolver: InputResolver` (ADR-0008), `sim_time: SimTime`, `sim_rng: SimRng` (ADR-0004) | ADR-0001, ADR-0004 |
| `SimTime` | `RefCounted` | `src/foundation/sim_time.gd` | `const TICKS_PER_SECOND := 60`; `ticks_per_second: int`, `dt: float` (read-only); `to_ticks(seconds) -> int` = sign(x) * floor(abs(x) + 0.5), x = seconds * ticks_per_second | ADR-0004 |
| `SimRng` | `RefCounted` | `src/foundation/sim_rng.gd` | xorshift32 from `rng_seed & 0xFFFFFFFF`; `next_u32()`, `next_below(n)`, `draw_count()`; no MVP consumer | ADR-0004 |
| `BattleClock` | `RefCounted` | `src/root/battle_clock.gd` | `MAX_TICKS_PER_FRAME := 3`, `STALL_SECONDS := 0.5`; `advance(delta) -> int`, `drop_backlog()`; owned by BattleWrapper, absent headless | ADR-0004 |

Catalogue IDs are `StringName` everywhere, signals included (`tower_id`, `def_id`, `source_id`); `slot_index`, `spawn_id`, resolver ids and `level` are `int` (ADR-0006, QQ-04 closed).

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
static func create(drag_slop: float, tap_slop: float, dev_error: Callable = Callable()) -> InputResolver   # null when invalid (ADR-0008 Decision 2)
static func target_ok(radius: float, width_dp: float) -> bool   # integer 48 dp check (Input Formulas)

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

# Read-only queries and recovery (ADR-0008).
func state() -> State                       # enum State { IDLE, PRESSED, DRAGGING, DEAD }
func centre_of(id: int) -> Vector2          # logs and tests only
func last_gesture() -> GestureRecord        # null before the first gesture; else a new copy
func recover_if_stuck() -> bool             # InputAdapter.flush() only, first

signal pressed(best_tap: int, best_drag: int, p: Vector2)
signal tapped(best_tap: int, p: Vector2)
signal ground_tapped(p: Vector2)
signal drag_started(best_drag: int, press_pos: Vector2, p: Vector2)
signal drag_moved(best_drag: int, press_pos: Vector2, p: Vector2)      # one per input call, never per frame
signal drag_ended(best_drag: int, press_pos: Vector2, release_pos: Vector2)
signal drag_cancelled(best_drag: int)
signal became_idle()                                                   # last signal of every exit to Idle
```
Invariants: ids start at 1 and are never reused; `NONE` marks an absent winner. `sink` is TAP-only: the target absorbs taps its owner ignores, without raising the press's slop. One active pointer. Winners and their discs are frozen at press (tie-break: priority, then squared distance, then id). Gesture calls made inside a handler queue FIFO and drain synchronously in the outermost call. No clock, no scene tree, no engine events. Non-finite positions and radii are dropped and reported through the injected `dev_error` (which calls `push_error`; `push_error` directly when none is given). ADR-0008 (Proposed) decides the internals: a value-only `Array` registry with no owner reference; winners and discs frozen as `float` scalars; `Vector2` only at the API; one FIFO queue in which each call commits then emits its batch; two-step cancel-then-press; a 64-call cap; `recover_if_stuck()`; `Battle.resolver`; `GestureRecord` read by the development-only `GestureLog`. ADR-0006 fixed the names (`tap`, `ground_tap` and `idle` became `tapped`, `ground_tapped` and `became_idle`; `pressed` is kept) and the payload types; ADR-0008 owns the internals.

### B3. Input adapter (ADR-0003)

```gdscript
class_name InputAdapter extends Node        # process_mode = PROCESS_MODE_ALWAYS
const MOUSE_POINTER := 1000                 # touches emulated from the mouse, when SP5 can tell them apart
signal lifecycle_paused()                   # the wrapper connects it to Flow.pause() and the HUD press clear
signal display_changed()                    # after a window-size or inset change
func attach(resolver: InputResolver, edge_reject_margin: float) -> void
func detach() -> void
func flush() -> void                        # frame step 0: queued calls to the resolver, in order
func cancel_all() -> void                   # the Battle input canceller (ADR-0003 Decision 9)
func set_presses_blocked(blocked: bool) -> void   # SP3 fallback only
func field_insets() -> FieldInsets          # field units; 0 on desktop
func field_width_dp() -> float
# Contract: every forwarded press is followed by exactly one release, cancel_pointer or cancel()
# for that index, even when a Control with mouse_filter = STOP lies under the drag.
# Presses from _unhandled_input; moves and releases of forwarded indices from _input (consumed).
# Calls cancel_all() on the four loss notifications and on a window-size change (ADR-0003).
```
ADR-0003 (Proposed) decides this block; each engine fact is a spike item (SP0 to SP13) answered by `prototypes/adr-0003-device-spike/`, with a stated fallback per outcome. Display: 540x960, `canvas_items`, `keep`, portrait, fullscreen on phones; taller phones letterbox; 360 dp logging guard. Only modal screens are tappable Controls; every other battle Control is `MOUSE_FILTER_IGNORE`. The Mobile Platform GDD (Vertical Slice) inherits the decision rather than blocking it (TD-ARCHITECTURE A3).

### B4. Battle and Builder (ADR-0001, ADR-0004)

```gdscript
class_name Battle extends RefCounted
func tick(dt: float) -> void      # the ONLY way simulation time advances.
                                  # Returns at once unless flow.phase() is WAVE or INTERMISSION
                                  # and halted() is false.
func halted() -> bool             # flow outcome WON, LOST or FATAL, or fatal_latch set
func ticks_run() -> int           # ticks that passed the gate (ADR-0004)
func between_ticks() -> bool      # false only while tick() runs (ADR-0004)
var sim_time: SimTime             # read-only; tick(dt) requires dt == sim_time.dt (ADR-0004)
var sim_rng: SimRng               # read-only; injected only where a GDD states a random rule (ADR-0004)
var input_record: InputRecord     # read-only; set by the Builder; the wrapper reads it in attach() (ADR-0003)
var resolver: InputResolver       # read-only; created in Builder step 2; the wrapper hands it to the adapter and owners (ADR-0008)
var flow: Flow                    # read-only sim members, one each (ADR-0001, ADR-0006 EMITTER_KEYS)
var combat: Combat                # ADR-0009 Decision 4
var enemy_wave: EnemyWave         # ADR-0009 Decision 7
var tower_sim: TowerSim           # ADR-0010 Decision 1
var hero_sim: HeroSim             # ADR-0010 Decision 1; hero_id() and burst_id() carry the Hero and Burst IDs to HeroInput and the HUD (ADR-0010 Decision 7)
var accessor: StatAccessor        # read-only; the one stat accessor (ADR-0005 Decision 1)
var stage_record: StageRecord     # read-only; path, slots, scene_ref (ADR-0011 Decision 3)
var visual_keys: VisualKeys       # read-only; StringNames only (ADR-0011 Decision 3)
var wave_records: Array[WaveRecord]  # read-only; the stage's Wave records for the HUD next-wave line (ADR-0005 Decision 8)
var rng_seed: int                 # read-only; the run seed, copied into the result snapshot and the run log (ADR-0004 Decision 7)
func emitters() -> Array[Object]  # ADR-0006 Decision 8
func cancel_input() -> void       # calls the canceller set by set_input_canceller (ADR-0003 Decision 9)

class_name BattleBuilder extends RefCounted
static func build(catalogue: Catalogue, stage_id: StringName, rng_seed: int, fatal_handler: Callable) -> Battle
```
Invariants: `build` touches no node, so bots and tests call it headless. It creates the per-battle FatalLatch first, then makes every connection in one function. It is never called from inside a signal. Injected callables are method Callables only: no lambda or `bind()` that captures a sim object, and no sim object holds a reference back to `Battle`, so dropping the `Battle` frees everything and the weakref test passes. Gameplay classes never read `Engine`, `Time`, `OS`, a timer or `await`.

### B5. Flow (ADR-0004, ADR-0006)

```gdscript
class_name Flow extends RefCounted
enum Phase { BUILD, WAVE, INTERMISSION, PAUSED, WON, LOST, FATAL }
func phase() -> Phase
func lives() -> int
func result() -> StageResult         # null before the outcome; built once at the outcome commit (ADR-0006 Decision 6)
func in_build() -> bool
func tick() -> void
var intermission_left: int           # integer ticks, never float subtraction
# Commands (between ticks; ADR-0010 Decisions 2 and 3, QQ-18 closed).
enum StartResult { OK = 0, HALTED = 1, NOT_BUILD = 2 }
enum CallResult  { OK = 0, HALTED = 1, NOT_INTERMISSION = 2, NOTHING_LEFT = 3 }
func start_wave() -> StartResult     # Start Wave in BUILD; a second tap finds no BUILD: NOT_BUILD
func call_early() -> CallResult      # Call during INTERMISSION; a call at 0 is NOTHING_LEFT, no signal
func pause() -> void
func resume() -> void
signal phase_changed(value: Phase)   # renamed from the GDDs' phase (TD-ARCHITECTURE B1, ADR-0006)
signal lives_changed(current: int)
signal wave_called_early(seconds_left: float)
```
Outcome commit order (Rule 15): set state and build the `StageResult`, then the tick gate stops time, then `cancel_input()`, then emit `phase_changed`. FATAL is a `Phase` value because Rule 15 has `phase_changed` name Won, Lost, Paused and Fatal, and Tower's chip listens for Fatal. AppRoot's own states (Boot, InStage, Fatal) are separate and live on AppRoot. Retry is an AppRoot latch, not a Flow command.

### B6. Combat (ADR-0009)

Copied from the Combat & Damage GDD.

```gdscript
class_name Combat extends RefCounted
enum SourceKind { TOWER, HERO, BURST }

func deliver(event: DamageEvent) -> float                            # applies min(amount, hp); only inside a tick
func apply_slow(enemy: Targetable, strength: float, seconds: float) -> void   # Combat converts seconds to ticks
func speed_factor(enemy: Targetable) -> float
func tick_status(roster: Array[Targetable]) -> void
func attach(t: Targetable, max_hp: float) -> bool                                           # ERR_ALREADY_ATTACHED, ERR_BAD_MAX_HP
func first_in(list: Array[Targetable], origin_x: float, origin_y: float, max_range: float) -> Targetable     # greatest distance; lowest spawn_id on ties
func nearest_in(list: Array[Targetable], origin_x: float, origin_y: float, max_range: float) -> Targetable
func all_in_radius(list: Array[Targetable], impact_x: float, impact_y: float, radius: float) -> Array[Targetable]
func is_dead(enemy: Targetable) -> bool
func hp_left(enemy: Targetable) -> float
func report_attack(source_kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float) -> void
func dealt_by_id(id: StringName) -> float
func dealt_by_kind(kind: SourceKind) -> float
func dealt_total() -> float
func hero_share() -> float
signal attack_fired(source_kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
signal damage_applied(source_kind: SourceKind, source_id: StringName, applied: float, position: Vector2, killed: bool, spawn_id: int)
```
Invariants: every HP change goes through `deliver`. Guards run in a fixed order (removed, amount, dead) and report named `push_error` codes. The parameter is `max_range` because `range` is a GDScript global. Combat reads no catalogue data. Helpers never mutate the list and skip the dead. View signals carry copied positions, and listeners never call `deliver`. ADR-0009 fixes the list type as `Array[Targetable]`, sim positions as float scalars (`Vector2` only in `report_attack` and the view signals), `attach` as the registration call, and `push_error` direct for Combat's guard codes (a scoped exception to ADR-0001 Decision 4).

### B7. Enemy and Wave (ADR-0009)

```gdscript
class_name EnemyWave extends RefCounted
func advance() -> void                      # EnemyWave owns wave_tick; returns at once if add_enemy fails
func reap() -> void
func start_next_wave() -> void              # parameterless; commits at wave_tick 0
func add_enemy(def_id: StringName, start_distance: float) -> bool   # EnemyWave and tests only
func roster() -> Array[Targetable]          # spawn_id order; caller must not hold it past its slot
func targets() -> Array[Targetable]         # targetable only: centre inside the 540x960 field
func wave_index() -> int                    # view-only read (ADR-0009, ratified ADR-0010)
func got_through_by_type() -> Dictionary    # view-only read (ADR-0009, ratified ADR-0010)
enum WaveState { WAITING, ACTIVE, FINISHED }
func wave_state() -> WaveState
func wave_tick() -> int
signal enemy_leaked(lives_cost: int)
signal enemy_killed(bounty: int)
signal wave_cleared(intermission_duration: float)
signal waves_completed()                    # renamed from waves_complete (ADR-0006, QQ-07)
```
The enemy stays a valid reference after removal (`removed` is set, the object is not freed). Lists are built as `Array[Targetable]` from the start, since typed arrays are invariant (ADR-0009 V2). `roster()` and `targets()` return EnemyWave's internal buffers, read-only by contract and size-checked at each `advance()` and `reap()`; a removed enemy leaves both before its signal fires. Constructor, loops and `add_enemy`: ADR-0009 Decision 7.

### B8. TowerSim and HeroSim commands (ADR-0010)

```gdscript
class_name TowerSim extends RefCounted
enum BuildResult   { OK = 0, HALTED = 1, BAD_SLOT = 2, BAD_TOWER = 3, SLOT_OCCUPIED = 4, NO_GOLD = 5 }
enum UpgradeResult { OK = 0, HALTED = 1, BAD_SLOT = 2, NO_TOWER = 3, MAX_LEVEL = 4, NO_GOLD = 5 }
func build(slot_index: int, tower_id: StringName) -> BuildResult
func upgrade(slot_index: int) -> UpgradeResult
func gold() -> int
func slot_count() -> int
func slot_tower(slot_index: int) -> StringName     # &"" when empty
func slot_level(slot_index: int) -> int            # 0 when empty
func slot_cooldown_left(slot_index: int) -> int
func slot_position(slot_index: int) -> Vector2     # view and bot read
func slows_applied() -> int
signal gold_changed(current: int)
signal tower_built(slot_index: int, tower_id: StringName)   # StringName: ADR-0006 (QQ-04)
signal tower_upgraded(slot_index: int, level: int)

class_name HeroSim extends RefCounted
enum PinResult   { OK = 0, HALTED = 1, BAD_POSITION = 2, OUT_OF_BOUNDS = 3, BUTTON_ZONE = 4 }
enum BurstResult { OK = 0, HALTED = 1, BUILD_PHASE = 2, NOT_PINNED = 3, NOT_READY = 4,
                   BAD_POSITION = 5, OFF_FIELD = 6, OUT_OF_REACH = 7 }
func pin(pos: Vector2) -> PinResult
func burst(aim_point: Vector2) -> BurstResult
# queries and counters: ADR-0010 Decision 7
signal hero_pinned(position: Vector2)
signal burst_started(aim_point: Vector2, telegraph_ticks: int)
```
Invariants: every command first checks the injected `between_ticks()` (`fatal`, then `HALTED`), then `halted()`. State is checked before geometry. A refusal mutates and emits nothing. All stats a command needs are read before any mutation. Enum values are explicit and never renumbered; names come from `find_key`. `chip_state()` is TowerInput's, not TowerSim's (Tower Rule 17). `Vector2` arguments are converted to float scalars on entry; stored positions are float pairs; position queries and the two view signals build `Vector2` on return (ADR-0009, ADR-0010 Decision 5).

### B9. Injected values and callables (ADR-0001)

| Name | Injected into | Meaning |
|---|---|---|
| `halted() -> bool` | EnemyWave, TowerSim, HeroSim, HudLogic; TowerInput, HeroInput (by the wrapper, ADR-0010) | `Battle.halted()`. Checked after every accessor read and every signal. |
| `between_ticks() -> bool` | TowerSim, HeroSim, Flow (changed 2026-11-04: EnemyWave takes none) | `Battle.between_ticks()`. Checked first in every command, in every build; false calls `fatal` (ADR-0010 Decision 2). |
| `in_build() -> bool` | HeroSim, HeroInput, HudLogic (changed 2026-11-04: TowerSim takes none, as implemented) | True while Flow is in BUILD. |
| `targets() -> Array[Targetable]` | TowerSim, HeroSim (EnemyWave owns it and takes none; noted 2026-11-04) | EnemyWave's `targets()`, so Tower and Hero never reference EnemyWave (Tower Rules 9, 13; Hero Rule 4). |
| `cancel_input() -> void` | Flow | `Battle.cancel_input`, which calls the canceller the wrapper sets to `InputAdapter.cancel_all` (empties the adapter queue, then the resolver's `cancel()`; ADR-0001 Decision 5, ADR-0003 Decision 9), so Flow never references the adapter or the resolver (TR-state-007). Headless, a no-op. |
| `left_handed: bool` | HeroSim, HeroInput, HudLogic | From the Input record, fixed per battle (Hero Rule 2, TR-hero-004). |
| `fatal(cause: String) -> void` | Builder, accessor, all sims | Sets the battle FatalLatch and the AppRoot FatalLatch. Idempotent. |
| `dev_error(msg: String) -> void` | EnemyWave, TowerSim, Flow, InputResolver (changed 2026-11-04: HeroSim takes none) | Development-error sink that survives release builds. Tests replace it. |
| `to_ticks(seconds: float) -> int` | Combat (its only injected callable, changed 2026-11-04), EnemyWave, TowerSim, HeroSim, Flow | `battle.sim_time.to_ticks`: sign(x) * floor(abs(x) + 0.5) with x = seconds * 60; non-finite gives 0; `dt` = 1/60 fixed at build (ADR-0004 Decision 6). |
| `wave_index() -> int` | Flow | `enemy_wave.wave_index`, read once to build the `StageResult` (Game State Rule 15; ADR-0006 Decision 6). |
| `dealt_by_kind(kind: Combat.SourceKind) -> float`, `dealt_total() -> float` | Flow | `combat.dealt_by_kind` and `combat.dealt_total`, read once to build the `StageResult` (ADR-0006 Decision 6). |
| `dt: float` | Flow, EnemyWave, HeroSim (and Combat through `to_ticks` only) | `battle.sim_time.dt`, the value 1/60 (ADR-0004). |

All are method Callables on objects the Builder owns (B4 rule).

### B10. HUD read surface (ADR-0006, ADR-0010)

The HUD reads, never writes: `Flow.phase()`, `lives()`, `intermission_left`, `result()`, `in_build()`; `TowerSim.gold()`, the per-slot reads, `slows_applied()`; `TowerInput.chip_state()`; `HeroSim` queries, counters, `cooldown_left()` and `burst_id()`; `EnemyWave.wave_index()`, `got_through_by_type()`; `Combat.hero_share()`. It listens to TowerInput's `slot_tapped` and `tower_inspected`. The cooldown total is `to_ticks(stat_float(burst_ctx, StatKeys.COOLDOWN))`, read by the HUD through its own burst context (ADR-0005 Decision 7). The result screen and run log read one `ResultSnapshot` (ADR-0010 Decision 11). `burst_button_centre()` is owned by the HUD; the wrapper reads it in `attach`, passes it to `HeroInput.attach` as a value, and re-reads it on every `display_changed` (`HeroInput.set_button_centre`, ADR-0010 Decision 8). HudLogic listens to `burst_started` (ADR-0006 P7) and reads the next-wave preview built from `Battle.wave_records` (ADR-0005 Decision 8). `ResultSnapshot` carries damage by source and by kind (ADR-0010 Decision 11).

### What cannot be tested headless

These run only in the editor or on a device. ADR-0007 Decision 12 lists them (M1 to M11) as manual evidence in `production/qa/evidence/`: the InputAdapter and Control event order; lifecycle notifications; `free()` vs `queue_free()` timing on retry; safe-area values; the catalogue load from an iOS export (Android deferred, ADR-0002 W2); draw-call and frame-time budgets. Everything in B0 to B2 and B4 to B9 runs headless, including the weakref test, provided the test itself holds no reference to the old battle.

## ADR Audit

### ADR Quality Check

Eleven ADRs exist (ADR-0001 to ADR-0011), all **Proposed**; `adr-dep-graph.sh` reports `ADRS: 11`, no cycle and no `NO_DEPS_SECTION` (the companion `adr-0007-lint-rules.md` is skipped because its first line is not an ADR title). `/architecture-review` 2026-11-05 checked them: every ADR has Status, Context, Decision, Consequences, ADR Dependencies, Engine Compatibility and GDD Requirements Addressed; 11 of 11 have an Engine Compatibility section pinned to 4.7.2; no deprecated API is used; no data-ownership or state-authority conflict. Its findings were applied on 2026-11-05: the ADR-0006 and ADR-0008 cycle was cut, ADR-0007's ADR-0006 edge moved to its Ordering Note, the nine minor conflicts and three wording risks were fixed, and the Required ADRs item 2 amendments were made (each ADR's Status note says "Amended 2026-11-05 after /architecture-review."). Still open: no ADR decides the renderer or the first target device (engine finding E1; planned ADR-0012), and the HIGH engine items E2 to E5 wait for their spikes.

Acceptance order (from `adr-dep-graph.sh`): ADR-0001, ADR-0002, ADR-0007, ADR-0005, ADR-0003, ADR-0009, ADR-0004, ADR-0006, ADR-0008, ADR-0010, ADR-0011. Only the user, or `technical-director` on the user's explicit confirmation, moves an ADR to Accepted.

### Traceability Coverage Check

Technical Requirements Baseline: **158 requirements from 8 GDDs, 158 registered, 0 provisional** (120 before 2026-11-05, 38 added by that review). The full per-requirement matrix is `docs/architecture/requirements-traceability.md` (158 rows); the review that built it is `docs/architecture/architecture-review-2026-11-05.md`.

| Status (review of 2026-11-05) | Count |
|---|---|
| Covered by an Accepted ADR | 0 |
| Covered by a Proposed ADR | 145 |
| Partial | 11 |
| **Gap** | **2** |

The two gaps: TR-hud-017 (HUD reads the Wave records), now decided by ADR-0005 Decision 8 (`Battle.wave_records`); and TR-data-021 (record ID stability), Vertical Slice scope with Save/Load. Of the 11 partials, the 2026-11-05 amendments address TR-state-003 (lint PHYS-1, ADR-0007), TR-state-013 (recording-fake seam, ADR-0007 Decision 5), TR-state-018 (Flow owns the wrong-phase checks, ADR-0006 Decision 7), TR-combat-013 (whole-tick budget, ADR-0004 Decision 10 and ADR-0009 Decision 9), TR-hero-004 (registry reworded; ADR-0010 Decisions 7, 8), TR-hud-010 (HudLogic on P7, ADR-0006), TR-hud-013 (per-source damage, ADR-0010 Decision 11) and TR-hud-018 (button centre re-read, ADR-0010 Decision 8). TR-data-003 and TR-data-015 wait for ADR-0012; TR-input-005 waits for spike SP5. The next `/architecture-review` recounts.

## Required ADRs

Eleven ADRs exist and are Proposed; one more is planned. The review labels P01 to P15 map as before. Version 1 proposed 15; four pairs were folded (Fatal Path into App Lifecycle, Determinism into the Tick ADR, Combat API into the Enemy Entity ADR, Dev Telemetry into the command and resolver ADRs). "Depends on" below is each ADR's own Depends On row, as `adr-dep-graph.sh` reads it.

| ID | Title | Layer | Depends on | Status | Review label | Engine risk |
|---|---|---|---|---|---|---|
| ADR-0001 | App Lifecycle, Composition Root and Fatal Path | Foundation | none | Proposed | P01, P06 | HIGH |
| ADR-0002 | Catalogue Storage Format, Manifest and Validation | Foundation | ADR-0001 | Proposed | P03 | HIGH |
| ADR-0003 | Input Adapter, Display Stretch and Platform Lifecycle | Foundation | ADR-0001, ADR-0005 | Proposed | P05 | HIGH |
| ADR-0004 | Fixed-Tick Clock, Tick Order, Frame Order and Determinism | Foundation | ADR-0001, ADR-0003, ADR-0005, ADR-0009 | Proposed | P02, P07 | HIGH |
| ADR-0005 | Stat Accessor and Read-Context Contract | Foundation | ADR-0001, ADR-0002 | Proposed | P04 | LOW |
| ADR-0006 | Battle Signal Contracts and View Allowlist | Foundation | ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0009 | Proposed | P10 | MEDIUM |
| ADR-0007 | Headless Test Harness, gdUnit4 and Layer Lint | Foundation | ADR-0001 (ADR-0006 in its Ordering Note, for the second activation step) | Proposed | P08 | MEDIUM |
| ADR-0008 | Input Resolver Core and Signal Contract | Foundation | ADR-0001 to ADR-0004, ADR-0006, ADR-0009 | Proposed | P09, part of P15 | MEDIUM |
| ADR-0009 | Enemy Entity, Roster and Combat API | Core | ADR-0001, ADR-0002, ADR-0005 | Proposed | P11, P12 | MEDIUM |
| ADR-0010 | Sim/Input Split, Command Result Codes and Dev Telemetry | Core | ADR-0001, ADR-0002, ADR-0004 to ADR-0009 | Proposed | P13, part of P15 | LOW |
| ADR-0011 | Battle Field Rendering and Draw-Call Budget | Presentation | ADR-0001, ADR-0003 to ADR-0007, ADR-0009, ADR-0010 | Proposed | P14 | MEDIUM |
| ADR-0012 | Renderer and First Target Device | Foundation | ADR-0001 (expected) | **Planned** (`/architecture-decision renderer and first target device`) | review 2026-11-05, Required ADRs item 1 | HIGH |

ADR-0012 decides Mobile versus Compatibility for a canvas-only game, and iPhone first versus Android first, with which renderer each device run records. It resolves engine finding E1 and TR-data-003 and TR-data-015, and may reopen ADR-0011's batching measurements. A later ADR on save-data ID stability and migration (TR-data-021) is due at Vertical Slice with Save/Load.

### What each ADR decides and which requirements it covers

The "Covers" lists are the planning assignment of the first 120 requirements. The 158-row matrix in `requirements-traceability.md` is the current mapping and wins where they differ.

**ADR-0001 App Lifecycle, Composition Root and Fatal Path** (Foundation). Decides: no autoloads, AppRoot states (Boot, InStage, Fatal), scene-free builder, injected callables (method Callables only, no capturing lambdas or bind), per-battle FatalLatch, push_error vs assert, dev-error sink, retry by dropping references and the weakref proof, teardown by `queue_free()` and never `free()` (Decision 7), Reduce Motion from the Input record read by AppRoot (Decision 8).
Covers (15): TR-data-004, TR-data-006, TR-data-009, TR-data-011, TR-input-012, TR-state-001, TR-state-002, TR-state-009, TR-state-011, TR-enemy-005, TR-enemy-012, TR-tower-006, TR-tower-013, TR-hero-004, TR-hud-006.

**ADR-0002 Catalogue Storage Format, Manifest and Validation** (Foundation). Decides: JSON data files and a JSON manifest (not `Resource`), typed read-only `RefCounted` records built after validation, schema-driven strict field checks, the export load proven on an iOS export first (Android deferred, W2), read-only proof by a canonical `to_dict()` snapshot (not `duplicate_deep()`), content tests.
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

**ADR-0009 Enemy Entity, Roster and Combat API** (Core). Decides: Targetable base class, Health and Status attachment, roster ownership and typed lists, path lookup, deliver guards, targeting helpers, the whole-tick budget that replaces TR-combat-013's 2 ms targeting figure (Decision 9).
Covers (16): TR-combat-001, TR-combat-002, TR-combat-003, TR-combat-004, TR-combat-005, TR-combat-006, TR-combat-007, TR-combat-008, TR-combat-013, TR-enemy-008, TR-enemy-009, TR-enemy-010, TR-enemy-011, TR-enemy-013, TR-tower-007, TR-hero-007.

**ADR-0010 Sim/Input Split, Command Result Codes and Dev Telemetry** (Core). Decides: HeroSim/TowerSim vs HeroInput/TowerInput, result enums with OK = 0, gold ownership, bot equivalence, run counters and run log.
Covers (10): TR-tower-001, TR-tower-002, TR-tower-008, TR-tower-009, TR-hero-001, TR-hero-002, TR-hero-009, TR-hero-012, TR-hero-015, TR-hud-013.

**ADR-0011 Battle Field Rendering and Draw-Call Budget** (Presentation). Decides: single _draw nodes, pools, draw order, path polygon, HUD draw budget, hit-flash shader question.
Covers (5): TR-combat-011, TR-enemy-015, TR-tower-015, TR-hud-001, TR-hud-015.

### Priority

**Must have before any code is written (Foundation, 8):** ADR-0001 to ADR-0008. ADR-0003 starts with a short verification spike on a device (event order, touch fields, lifecycle notifications, safe area), because ADR-0004 and ADR-0008 rely on what it finds. Treat that spike as real work, not paperwork.

**Planned, before the first device run (Foundation, 1):** ADR-0012 Renderer and First Target Device. It fixes which renderer every device result records, so ADR-0011's batching numbers mean something.

**Must have before the named system's first story (Core, 2):** ADR-0009 before any Combat or Enemy & Wave story (the Combat GDD names the enemy object kind and Health/Status attachment as a prerequisite). ADR-0010 before any Hero or Tower story (HeroInput and TowerInput placement).

**Can defer (Presentation, 1):** ADR-0011, to the first phone build, when draw calls are first measured.

### Decisions made in this document that need no separate ADR

These follow directly from the GDDs and the gate reviews, and the ADRs above cite them: no autoloads; simulation classes extend `RefCounted`; presentation never feeds the sim; commands run between ticks and the tick gate lives inside `Battle.tick` (both ratified in ADR-0004); `Targetable` is a Core base class; result enums put `OK = 0` first; progression systems own their save schema; code root `src/` with one folder per layer.

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
| QQ-01 | Tick driver: custom accumulator in `_process` or `_physics_process`; tick rate (60 Hz proposed); `MAX_TICKS_PER_FRAME`; behaviour on a frame stall. | High | ADR-0004 (Proposed): `_process` accumulator, 60 Hz, clamp 3 (V6 sets 2 to 4), stall over 0.5 s runs no ticks |
| QQ-02 | Stretch mode and aspect (`project.godot` sets none; 4.7 changed new-project defaults), minimum width (360 dp proposed), whether a taller phone letterboxes or reveals the off-field entry. Layout rules L3, L5 to L7 depend on the answer. ADR-0003 decides; the Mobile Platform GDD inherits. Proposed in ADR-0003: `canvas_items`, `keep`, portrait, fullscreen on phones, 360 dp guard (log only), taller phones letterbox (off-field entry not revealed at MVP; C3, C4 confirmed by the user 2026-11-04). | High | ADR-0003 (Proposed) |
| QQ-03 | Catalogue format: typed `Resource` or JSON; how missing fields and fractional integers are caught; how read-only is enforced and snapshot-tested; proof it loads from an export. | High | ADR-0002 (Proposed): JSON and a JSON manifest, typed `RefCounted` records, canonical snapshot (not `duplicate_deep()`), export load on the iPhone first |
| QQ-04 | Type of `tower_id` and other IDs across signals: `StringName`, `String` or `int`. Proposed in ADR-0006: `StringName` for every catalogue ID, `int` for slot, spawn and resolver ids; no payload carries a sim object. | Medium | ADR-0006 (Proposed) |
| QQ-05 | `Vector2` is documented as 32-bit in a stock build but unverified on 4.7. PinGeometry avoids `Vector2` methods until it is. Float results may differ between x86 and ARM, so bot baselines are kept per architecture. | Medium | ADR-0004 (float policy); ADR-0009 makes every sim position a float scalar pair and verifies `Vector2` precision (V1); float policy and `tests/baselines/<arch>/` in ADR-0004 Decision 9 (Proposed) |
| QQ-06 | Engine event order: does input arrive before `_process`; Control event order against `_unhandled_input`; which notifications fire on Android and iOS for pause and focus loss; moves and releases delivered after a `cancel` on focus return; a release synthesised before a focus loss. Spike items SP1, SP2, SP3, SP10, SP11; kit in `prototypes/adr-0003-device-spike/`. | High | ADR-0003 (spike) |
| QQ-07 | Signal names that still break the past-tense naming rule: `tap`, `ground_tap`, `pressed`, `idle` (Input GDD) and `waves_complete` (Enemy & Wave GDD). `phase` is already renamed `phase_changed` here. Rename (for example `tapped`, `ground_tapped`, `became_idle`, `waves_completed`) or record an exception, before ADR-0008 and before any test uses them, and update the GDDs to match. Proposed in ADR-0006: those four renames, `pressed` kept, no exception; GDDs updated in the same change. | Medium | ADR-0006 (Proposed) |
| QQ-08 | Technical-director acceptance of four changes the GDDs make to earlier notes: composition root as a scene-free builder; ProjectileSpawner cut; the one tick order; path and slots moved from the stage scene to the Stage record. The TD-ARCHITECTURE review judged all four sound on technical merit; acceptance is recorded only when the ADRs are Accepted, on the user's confirmation. ADR-0009 Decision 8 states the ProjectileSpawner cut (a future spawner calls `deliver`) and the stage-record move. | High | ADR-0001, ADR-0004, ADR-0009; ADR-0004 Decision 4 states the one tick order (Proposed) |
| QQ-09 | Where the Reduce Motion setting lives, before Settings (Alpha) exists. | Low | ADR-0001 Decision 8 (Proposed): the Input record's `reduce_motion`, read by AppRoot and passed to `wrapper.attach` |
| QQ-10 | Art bible §8 budgets a hit-flash shader; the Combat GDD uses none. | Low | ADR-0011 (Proposed): zero CanvasItem shaders and particles at MVP; flash is an alpha disc; V5 measures shader cost for a Vertical Slice reopen. Art bible §8 edit applied 2026-11-04, confirmed by the user as project owner (art-director and technical-artist not consulted separately) |
| QQ-11 | Unmeasured budgets: the frame split in Data Flow 10, 60 draw calls, 256 MB, about 400 range checks under 2 ms per tick, catalogue load at most 1000 ms median on an Adreno 5xx-class device. All need a device run at the first phone build. | Medium | ADR-0004 (frame split, per-tick 1.33 ms, V6), ADR-0011 (Proposed: per-node draw-call ceilings summing to 34 of 60, V1/V2 before acceptance, A1 at the first phone build), performance-analyst |
| QQ-12 | No Mobile Platform & Performance GDD yet. A large top inset collides the HUD band with the arc's top panel and prompt. | Medium | Mobile Platform GDD |
| QQ-13 | `tests/README.md` is stale: gdUnit4 is now in `addons/` and the class cache is tracked in git. Whether the CI test command needs a prior `--import` step on a fresh clone. | Low | ADR-0007 Decision 2 (Proposed): import before every run, retry once on an exit above 128; 101 and zero tests fail; README rewritten; V4, V5 |
| QQ-14 | Stage tooling: a converter or editor for point-list stages before about 20 stages exist. | Low | tools-programmer, after MVP |
| QQ-15 | GDScript 4.7 pitfalls have no rule yet: a typed-method override needs an explicit `return`; packed-array element writes skip setters; lambdas capture locals by value; signal parameter types are not checked at `emit()`. Turn them into Required and Forbidden rules. | Medium | ADR-0007 Decision 11 (Proposed); `/create-control-manifest` extracts them |
| QQ-16 | Every `class_name` is global. Short names (`Flow`, `Combat`, `Battle`, `Catalogue`, `Clock`, now `BattleClock`) risk collisions with engine or addon classes. Prefix them or lint for collisions. | Low | ADR-0007 Decision 10 (Proposed): no prefix; NAME-1 to NAME-4 on every run; V6 checks every ADR `class_name` (derived scan) against `ClassDB` |
| QQ-17 | Does a method `Callable` hold a strong reference to its object on 4.7? The retry weakref test depends on the answer. | Medium | ADR-0001 (Proposed): V1 recorded 2026-11-04, a method Callable holds an ID only; teardown uses `queue_free()` (Decision 7) |
| QQ-18 | Flow's command method names and their result enums (`start_wave`, `call_early`, `StartResult`, `CallResult`) are proposed here; the Game State GDD names the actions but not the methods. | Low | ADR-0010 (Proposed): names kept; `StartResult { OK, HALTED, NOT_BUILD }`, `CallResult { OK, HALTED, NOT_INTERMISSION, NOTHING_LEFT }` |
