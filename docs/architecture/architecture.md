# TowerRiot: Master Architecture

## Document Status
- Version: 4 (v2 revised after TD-ARCHITECTURE and LP-FEASIBILITY CONCERNS; v3 matches the cross-GDD blocker fixes and the second architecture review; v4 brings the text in line with ADR-0001, ADR-0002 and ADR-0003, accepted 2026-11-04)
- Last Updated: 2026-11-04
- Engine: Godot 4.7.2 (GDScript, Mobile renderer, Godot Physics 2D). Pinned in `docs/engine-reference/godot/VERSION.md`.
- GDDs Covered (8 MVP systems): `data-config-pipeline`, `input-gesture-resolver`, `game-state-stage-flow`, `combat-damage`, `enemy-wave`, `tower-system`, `hero-system`, `battle-hud`. Context only: `game-concept`, `systems-index`.
- Vertical Slice and Alpha systems (14 of 22) have no GDD yet. They appear in the layer map as reserved slots with the seams MVP code must leave for them. This document is revised when those GDDs exist.
- ADRs Referenced: **Accepted** (by the user, 2026-11-04): ADR-0001 App Lifecycle, Composition Root and Fatal Path; ADR-0002 Catalogue Storage Format, Manifest and Validation; ADR-0003 Input Adapter, Display Stretch and Platform Lifecycle. **Proposed, not yet written**: ADR-0004 to ADR-0011 (numbers provisional until `/architecture-decision` assigns them). Version 1 proposed 15; four pairs were folded together to cut scope for a solo developer. A contract that an accepted ADR decides cites that ADR. A contract that a GDD defers to a proposed ADR is still a working default, not a decision, and names the ADR that will decide it.
- Technical Requirements: 121, all registered in `docs/architecture/tr-registry.yaml` (TR-data, TR-input, TR-state, TR-combat, TR-enemy, TR-tower, TR-hero, TR-hud). Coverage by accepted ADRs: 36 of 121, of which 31 in full and 5 in part (see Traceability Coverage Check).
- TD-ARCHITECTURE: 2026-11-03, REVISED after CONCERNS. v1 findings B1 to B4 and A3 (blocking) and A1, A2, A4 to A10 (advisory) applied in v2. A11 (acceptance of the four GDD amendments) waits for the ADRs (QQ-08). v2 has not been re-reviewed.
- LP-FEASIBILITY: 2026-11-03, REVISED after CONCERNS. v1 findings 1 to 7 (blocking) applied in v2, except finding 1's note that `sink` was invented: the Input GDD defines it as a TAP-only `bool`, and v2 keeps it with that type. Advisory 8 to 15 applied or carried into the named ADRs. v2 has not been re-reviewed.

## Engine Knowledge Gap Summary

The model's training covers Godot up to about 4.3. Versions 4.5, 4.6 and 4.7 are post-cutoff. The installed editor matches the pin (4.7.2).

| Domain | Risk for this project | Why | What it touches |
|---|---|---|---|
| Input (touch, mouse emulation) | **HIGH** | 4.7 mouse and keyboard no longer report device `0`. 4.6 split touch focus from keyboard focus. `modules/input.md` has no touch coverage, so every touch API claim in the GDDs is unverified. | Input adapter, resolver, HUD Controls, all hit targets |
| UI and display (stretch, safe area) | **HIGH** | 4.7 changed stretch defaults for new projects (`canvas_items` / `expand`). Set explicitly by ADR-0003: `canvas_items` + `keep` at a 540x960 viewport, so the new-project defaults never apply. The key names and effective values stay unverified until spike check S9; the safe-area values until S7. The 540x960 field space, layout rules L3 and L5 to L7 and the HUD layout all depend on it. | Display setup, every field-unit conversion, HUD layout |
| GDScript language | **HIGH** | 4.7: an override of a typed method inherits the return type and needs an explicit `return`. Packed array element writes skip the property setter. 4.5 added `@abstract` and variadic `...args`. Not new, but it bites here: lambdas capture locals by value in every Godot 4 version, and signal parameter types are not checked at `emit()`. | Every `.gd` file; base classes; signal handlers; the Builder's injected callables |
| Rendering (2D, Mobile renderer) | **MEDIUM** | 4.7: `CanvasItem` lines lose their antialiasing feather and look thinner. The Mobile renderer reference is desktop-leaning. The 60 draw-call budget is a proposal, not measured. | Field views, HUD `_draw`, path polygon |
| Resources and file access | **MEDIUM** | `duplicate()` on nested resources is deprecated for `duplicate_deep()` (4.5). `FileAccess.store_*` returns `bool` (4.4). ADR-0002 reads the catalogue as JSON text through `FileAccess` and snapshots it by a schema walk, so it uses neither call. How an Android export packs `.json` files is unverified (ADR-0002 X1, X2). | Catalogue load, run log, save/load (VS) |
| App lifecycle (pause, focus, background) | **HIGH, unreferenced** | The GDDs name `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_APPLICATION_PAUSED` and `NOTIFICATION_WM_WINDOW_FOCUS_OUT`. None is in the pinned reference. ADR-0003 listens to the union of the focus-out, paused and window-focus notifications plus `NOTIFICATION_WM_GO_BACK_REQUEST`, so it holds whichever fire; spike check S5 records which do. | Pause rule (TR-state-010), held-press clearing |
| Audio | **MEDIUM** (Alpha) | 4.7 `area_mask` default on `AudioStreamPlayer2D` changed to `0`. | Audio system, not before Alpha |
| Physics | **LOW** | The simulation uses no physics bodies or areas (Flow Rule 4). The 4.7 physics changes are all Jolt 3D. | None at MVP |
| Animation, Navigation, Networking | **N/A** | No skeletal animation, no pathfinding (the hero pins), no networking. | None |

Rule for this document: any engine behaviour that sits in a HIGH row is written as **NEEDS VERIFICATION** until an ADR author has checked it against the live 4.7 documentation or a device.

Owner of each HIGH row: Input and app lifecycle, ADR-0003 (accepted; spike S0 still to run). UI and display, ADR-0003 (accepted). A row moves out of HIGH only once the S0 check behind it passes. GDScript language, ADR-0007 and the control manifest (QQ-15). Medium rows: rendering, ADR-0011; resources and file access, ADR-0002 and ADR-0010; audio, the Audio GDD (Alpha).

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
| 21 | Settings & Accessibility | Alpha | Presentation | Owns Reduce Motion from Alpha. Until then the value sits in the Input record and reaches views through `PresentationSettings` (ADR-0001, QQ-09 resolved) |
| 22 | Cross-Tree Synergies (full) | Alpha | Feature | Reserved |

Note on requirement tags: the `Layer` column in `requirements-traceability.md` tags each *requirement* by the kind of work it asks for. It does not override the system layer above. Enemy & Wave, Tower and Hero requirements are tagged Core there because they run inside the tick; their module layer is Feature, as in the systems index.

### Seams MVP code must leave for later tiers

| Later system | Seam MVP code must keep |
|---|---|
| Stat & Modifier Resolution (VS) | Every modifiable value is read through the one stat accessor at use time, never cached (TR-data-008). The resolver replaces the accessor's internals with no call-site change. Modifier source tags are reserved now. |
| Save/Load (VS) | Progression systems expose `to_dict()` / `from_dict()` with a version field and never call Save. MVP has nothing to save, so no save code is written, but no MVP system may hold progression state in a global. |
| Stage Progression (VS) | Flow keeps its result (outcome, last wave started, lives left, Combat per-source damage) readable after the outcome (TR-state-006, TR-combat-005). |
| Skill Tree / Hero Weapons (VS) | Hero and Tower read stats through the accessor with a read context holding `def_id`, so a tree node changes a stat without touching Hero or Tower code. |
| Settings (Alpha) | Views read Reduce Motion and the hand flag only from the injected `PresentationSettings`. AppRoot fills it once from the Input record at MVP; at Alpha, Settings becomes its source and no view changes (ADR-0001). |

## Module Ownership

Naming follows `project.yaml`: classes PascalCase, files snake_case, signals past tense. Signal names that break the past-tense rule are listed in QQ-07.

Code root is `src/` (Godot). Proposed folders, one per layer: `src/foundation/`, `src/core/`, `src/feature/`, `src/presentation/`, `src/root/`. Tests mirror them under `tests/unit/` and `tests/integration/`.

### Foundation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **Catalogue** (Data & Config) | The Ready catalogue: typed read-only `RefCounted` records (Tower, Enemy, Wave, Stage, Hero, Burst, Input, plus `TowerLevel`, `WaveGroup`, `PinShape`). The manifest (`manifest.json` in the data root). Load state (Unloaded, Loading, Ready, Failed). Holds no per-battle reference. | `load_manifest(manifest_path, data_root) -> LoadResult` (the only `FileAccess` user), `from_texts(...)` and `from_documents(...)` (no I/O, for tests); typed lookups `tower(id)` to `burst(id)`, lists per type in manifest order, `type_of(id)` | JSON data files listed in the manifest | `FileAccess` + `JSON` (MEDIUM; Android export packing unverified, ADR-0002 X1, X2). No `ResourceLoader` for data and no `duplicate_deep()`: `CatalogueSnapshot` walks the schema (ADR-0002) |
| **Validator** (inside Data & Config) | Schema tables in `schema.gd`, one per record type. Error list `{code, source, record_id, field}` plus a display-only `detail`. Tiers 0a (manifest and files) and 0b (types) stop on an error; Tiers 1 to 4 collect every error. | Runs inside `from_texts` and `from_documents` (ADR-0002) | Parsed JSON documents | None (plain GDScript) |
| **StatAccessor** (Data & Config) | Stat-key vocabulary and int/float type per key. Nothing else; no stored values. One per battle, built by the Builder (ADR-0001). | `stat_int(ctx, key) -> int`, `stat_float(ctx, key) -> float`; `is_tower(id)`, `level_count(def_id)` (non-fatal, moved here from the catalogue by ADR-0002); a type mismatch or bad call goes to the injected failure handler | Catalogue; later Stat & Modifier | None |
| **InputResolver** | Hit-target registry, the four-state machine, the FIFO re-entrancy queue, the frozen winners of the current press. No clock, no scene. | `press`, `move`, `release`, `cancel_pointer`, `cancel`; `register`, `unregister`, `set_centre`, `set_enabled`; signals `pressed`, `tap`, `ground_tap`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `idle` (payloads in B2) | `drag_slop`, `tap_slop` from the Input record, passed to `create()` by the Builder | None |
| **InputAdapter** (the only engine-facing input code; ADR-0003) | Translation of engine events to the five resolver calls (presses from `_unhandled_input`, endings of forwarded pointers from `_input`); the `_down` set; the modal press gate; edge and safe-area rejection against the battle's `FieldInsets`; dropping of emulated pointer events; lifecycle and resize `cancel()` calls | `setup(resolver, edge_reject_margin, insets, dev_error)`, `set_presses_blocked(blocked)`; signal `lifecycle_paused()`, wired to `Flow.pause` through `view_wiring` | Godot input events, `DisplayServer`, viewport | `InputEventScreenTouch`, `InputEventScreenDrag`, `is_canceled()`, `InputEvent.DEVICE_ID_EMULATION` (**HIGH, NEEDS VERIFICATION**, S2, S4); `_unhandled_input` vs `Control` ordering (**HIGH**, S1, S3); `Node.PROCESS_MODE_ALWAYS` (LOW); `DisplayServer.get_display_safe_area()` (**HIGH**, S7); `Viewport.size_changed` (LOW, S6); app lifecycle notifications (**HIGH**, S5); mouse device ID change (4.7, handled: events are told apart by class) |
| **SafeAreaMath**, **FieldInsets** (ADR-0003) | Pure inset maths: window-pixel safe rect to field-unit insets, net of the letterbox; dp-per-unit guard; rejected-zone test. `FieldInsets` holds `top`, `bottom`, `left`, `right` in field units, read-only by contract | `field_insets(...)`, `dp_per_unit(...)`, `is_rejected(...)` | Values passed in by `BattleWrapper` | None (pure); the inputs come from `DisplayServer` (**HIGH**, S7, S8) |
| **FatalLatch** (ADR-0001) | One per battle plus one on AppRoot. Pure: keeps the first cause, counts later calls, idempotent. No screen, no scene, no catalogue. | `fatal(cause)` (injected as a `Callable`), `is_fatal()`, `first_cause()`; signal `latched(cause)`, once. First call: forward if built with a forward Callable, else `push_error`; then emit | Nothing | `push_error` (LOW; release-build output checked by ADR-0001 V8). `assert` is never used for release-relevant checks (stripped in exports) |
| *Mobile Platform (VS)* | Inherits `SafeAreaMath`, `FieldInsets`, the stretch settings and the minimum size guard from ADR-0003. Owns gesture insets (QQ-21), export presets, effect pooling, particle caps | Reserved | | `DisplayServer` (HIGH) |
| *Save/Load (VS)* | Save file, version field, migration | Reserved | | `FileAccess` (MEDIUM) |

### Core

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **Flow** (Game State, pure object) | Stage state machine (Build, Wave, Intermission, Paused, Won, Lost, Fatal). Lives. `intermission_left` as integer ticks. The stage result. The remembered phase while Paused. | `phase()`, `lives()`, `result()`, `in_build()`, `intermission_left`; commands `start_wave()`, `call_early()`, `pause()`, `resume()` (names proposed, QQ-18); signals `phase_changed`, `lives_changed`, `wave_called_early` | Enemy & Wave signals (`wave_cleared`, `waves_complete`, `enemy_leaked`); injected `cancel_input()`, `wave_index()`, `to_ticks` and the dev-error sink; the battle FatalLatch's `latched` signal (ADR-0001); the adapter's `lifecycle_paused` and the Paused screen's `tapped`, both wired by the wrapper through `view_wiring` (ADR-0003) | None |
| **Combat** | `Targetable` base class, `DamageEvent` value, one Health and one Status per target, per-source damage counters. | `deliver(event) -> float`; `apply_slow`; `speed_factor`; `tick_status(roster)`; `first_in`, `nearest_in`, `all_in_radius`; `dealt_by_id`, `dealt_by_kind`, `dealt_total`, `hero_share`; `is_dead`, `hp_left`; `report_attack`; signals `attack_fired`, `damage_applied` | Values passed in by callers; `to_ticks` and `dt` injected at build | None (pure) |
| *Stat & Modifier (VS)* | Modifier stack, fixed evaluation order | Behind `StatAccessor` | Catalogue, tree nodes | None |

### Feature

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **EnemyWave** | Roster (sole owner of enemies), wave state machine, cached positions along the path polyline, `spawn_id` counter | `roster()`, `targets()` (both in `spawn_id` order, valid for the slot only); `advance(tick)`, `reap()`, `start_next_wave()`, add-enemy step; signals `enemy_leaked(lives_cost)`, `enemy_killed(bounty)`, `wave_cleared(intermission_duration)`, `waves_complete` | Stage and Wave records (direct), stats via accessor, Combat attach call, injected `halted()` and error sink | None in the sim. Views use `CanvasItem._draw` (see Presentation) |
| **TowerSim** | Gold (non-negative int), slots, towers, per-tower `cooldown_left` (ticks) | `build(slot_index, tower_id) -> BuildResult`, `upgrade(slot_index) -> UpgradeResult`, `tick()`, `slot_state()`, `chip_state()`, `gold()`; signals `gold_changed`, `tower_built`, `tower_upgraded` | `slot_positions` from the Stage record; accessor; `enemy_killed` straight from EnemyWave and `wave_called_early` from Flow (both wired by the Builder); injected `targets()` and `halted()`; Combat helpers | None |
| **HeroSim** | Hero position, pin target, pin state, burst state, cooldown, telegraph, run counters | `pin(pos) -> PinResult`, `burst(pos) -> BurstResult`, `tick()`, read-only queries (`position`, `pin_target`, `pin_state`, `burst_state`, `cooldown_left`), counters; signals `hero_pinned`, `burst_started` | Stage record (`hero_start`, `pin_rect`, `pin_exclusion`), accessor, Combat, injected `targets()`, `halted()`, `in_build()` and `left_handed` | None |
| **PinGeometry** | Pure clamp and validity maths in float scalars | `is_valid(pos) -> PinResult` (`OUT_OF_BOUNDS`, `BUTTON_ZONE` or `OK`, per Hero Rule 14), `clamp(pos)` | Pin rect and exclusion segments | None (avoids `Vector2` methods on purpose, see QQ-05) |
| *Stage Progression, Skill Points, Skill Tree, Hero Weapons, Synergies (VS/Alpha)* | Reserved | | | |

### Presentation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **HudLogic** | HUD presentation state (button arm model, arc state, snapshot). No gameplay state. | `advance(ms)`, view-model reads | Flow, TowerSim, HeroSim, EnemyWave, Combat (read-only), accessor for costs and the Burst `cooldown`, injected Burst ID | None |
| **HudTopBand** | Display-only `Control`s that ignore input (`mouse_filter = MOUSE_FILTER_IGNORE` on each node, linted; ADR-0003) | None | HudLogic | `Control`, `mouse_filter` (HIGH, 4.6 dual focus; avoided with `focus_mode = FOCUS_NONE`) |
| **HudField** | One `_draw` for field art; hit targets are resolver discs | None | HudLogic, resolver registry | `CanvasItem._draw` (MEDIUM, 4.7 line feather) |
| **ResultScreen, PausedScreen** (each a `TapScreen`, ADR-0003) | Full-rect modal `TapScreen`s: `MOUSE_FILTER_STOP`, `focus_mode = FOCUS_NONE`, mouse family only, `accept_event()` on every pointer event. Retry and Play again are `TapScreen` regions | Signal `tapped()` (on the release of a press it saw); `clear_press()`. Retry calls `AppRoot.request_retry()`; Paused `tapped` reaches `Flow.resume` through `view_wiring` | Result snapshot | `Control._gui_input`, emulated mouse from touch, press consumption before `_unhandled_input` (**HIGH, NEEDS VERIFICATION**, S2, S3 and the TapScreen check) |
| **HeroInput** | Aim state machine (Idle, Cancelling, Live), aim-point re-clamp, cancel hysteresis | `update()`, `cooldown_digit()` | Resolver signals, HeroSim queries, `burst_button_centre()` from the HUD | None |
| **TowerInput** | Slot and chip discs, `ChipWindow` | `slot_tapped`, `tower_inspected` | Resolver, TowerSim, Flow `phase` | None |
| **ChipWindow** | Real-time upgrade-chip timing | `advance(ms)` | Fed by the wrapper each frame | None |
| **Field views** (enemy, tower, combat, path) | Pools, draw order, flash markers (16 max), enemy view pool (at least 48) | None | `roster()`, `slot_state()`, Combat view signals | `CanvasItem._draw`, `draw_polyline` or a baked polygon (MEDIUM, **NEEDS VERIFICATION** for 90 degree corners at width 72) |
| **RunLog / GestureLog** (dev only) | JSONL records, gesture records | Injectable sink | Signals only | `FileAccess` append (MEDIUM; check the `bool` return). Decided in ADR-0010 and ADR-0008 |

### Composition Root

All rows below are decided by ADR-0001, except where a row names another ADR.

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **AppRoot** (main scene `res://src/root/app_root.tscn`, no autoload) | App states `BOOT`, `IN_STAGE`, `FATAL` (`FATAL` is absorbing). The Ready catalogue for the session, or the failed `LoadResult`. The app-level FatalLatch. The retry latch. `PresentationSettings`. The current `Battle` and `BattleWrapper`. | `state()`, `request_retry()`; starts the catalogue load; builds battles and tears them down from its own `_process`, fatal first | Catalogue, FatalLatch, BattleWrapper scene | `Node`, `PackedScene`, `remove_child()` then `queue_free()` for the wrapper, never `free()` (that no callback reaches a removed subtree is checked by V6), `weakref()` (LOW) |
| **Builder** (`build(catalogue, stage_id, rng_seed, fatal_handler)`) | Nothing persistent. Creates the battle FatalLatch first, then one `StatAccessor`, the resolver and every sim, and records every connection in the battle's `Wiring`. Checks the battle latch after each step and returns `null` once it is set. | Returns a `Battle`, or `null` | Every sim module | `Signal.connect(Callable)` (LOW). No `CONNECT_DEFERRED` on gameplay signals (TR-enemy-004). Injected callables are method Callables on objects that `Battle` or `AppRoot` holds: no lambda, no `bind()` with a sim argument. The design holds whether Callables are strong or weak; V1 records which (QQ-17) |
| **Battle** (`RefCounted`) | The sims, the battle FatalLatch, the resolver, and private strong members `_halt_gate`, `_tick_math`, `_dev_error_sink`, `_stat_accessor`, `_wiring`, so every injected Callable has a live target | `tick(dt)`, `halted()` (pass-through for the wrapper and tests), `unwire()` | Built by the Builder | None |
| **HaltGate** (`RefCounted`) | Holds Flow and the battle FatalLatch | `halted()`: true on `WON`, `LOST` or `FATAL`, or when the battle latch is set; false while `PAUSED`. Injected into the sims as `HaltGate.halted` | Flow, battle FatalLatch | None |
| **Wiring** (`RefCounted`) | A record of (Signal, Callable) pairs. Two per battle: the Builder's (held by `Battle`) and the wrapper's `view_wiring` | `connect_recorded(sig, target)` (a duplicate pair goes to the dev-error sink), `disconnect_all()` (idempotent) | Dev-error sink | `Signal.connect()`, `disconnect()`, `is_connected()` (LOW) |
| **DevErrorSink** (`RefCounted`) | Nothing | `report(msg)`: `push_error` in every build, never halts. Tests inject a recording fake | Nothing | `push_error` (LOW) |
| **PresentationSettings** (`RefCounted`) | `left_handed`, `reduce_motion`, read once from the Input record by AppRoot (QQ-09) | Read-only fields for HeroInput, HudLogic and every view | Input record | None |
| **BattleWrapper** (scene) | The Clock: real-time accumulator, catch-up clamp (max ticks per frame), accumulator zeroed on `phase_changed(PAUSED)` (ADR-0004). The InputAdapter, the `FieldInsets` (mobile only, read once at build, ADR-0003), HeroInput, TowerInput, HudLogic, the HUD, the `TapScreen`s and the field views. Its own `view_wiring` for every connection to a sim signal. No gameplay logic. Absent headless. | None | `Battle` (`battle.input_resolver`), `PresentationSettings` | `Node._process` (LOW); `_process` vs `_physics_process` decided in ADR-0004; `create_tween()` on its own nodes only, no SceneTree tween or timer |
| **FatalScreen** (`class_name FatalScreen extends Control`, built in code, not a scene) | Loads no `.tscn`, font, texture or catalogue data; default theme and font; full-rect anchors. Shown by AppRoot. | `show_cause(first_cause, errors)` | The app latch's first cause and AppRoot's kept `LoadResult` errors | `Control`, `Label` with `AUTOWRAP_WORD_SMART`, `ScrollContainer` (LOW). Debug builds (`OS.is_debug_build()`) show the cause and each `ValidationError` by file, record and field; release builds show one generic line |

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

Flows 4, 5 and 7 follow accepted ADR-0001, and flows 1 and 6 follow accepted ADR-0003 (step 2 of flow 4 follows ADR-0002). Every other flow is a **working default** drawn from the GDDs, which the named proposed ADR ratifies.

### 1. Frame update path

```
Engine delivers input events (before this frame's _process; NEEDS VERIFICATION, ADR-0003 check S1)
  _input            ──► InputAdapter: moves, releases, cancels of pointers it forwarded a press for
  GUI               ──► modal TapScreens (STOP) take presses; other Controls IGNORE
  _unhandled_input  ──► InputAdapter: presses (gate open, inside the field, not in a rejected zone)
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
| Touch/mouse events | Godot | InputAdapter (presses after GUI, endings before GUI); TapScreen (mouse family only) | Engine callback |
| Five resolver calls | InputAdapter | InputResolver | Synchronous call |
| Gesture signals | InputResolver | HeroInput, TowerInput, HudLogic | Signal (synchronous) |
| Commands | HeroInput, TowerInput, HudLogic, bots | HeroSim, TowerSim, Flow | Synchronous call, **only between ticks**, returns a result enum |
| `tick(dt)` | Clock (BattleWrapper) | Battle | Synchronous call; gated inside Battle |
| View reads | Views | Sim modules | Read-only query |

Rule: commands run from the input call stack, before the frame's ticks, so the bonus the HUD shows equals the bonus paid (TR-hud-005). Whether input is delivered before `_process` on 4.7 is **NEEDS VERIFICATION**: ADR-0003 check S1 tests it, and if it fails ADR-0004 queues commands and drains them at the start of its tick driver. ADR-0004 owns the frame order that relies on it. `MAX_TICKS_PER_FRAME` is an explicit output of ADR-0004.

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
| `lives_changed(current)`, `phase_changed(value)`, `wave_called_early(seconds_left)` | Flow | HUD, TowerSim (`wave_called_early`, and `phase_changed` for the chip), BattleWrapper (zeroes the accumulator on PAUSED), views | The GDD names the signal `phase`; renamed here because a member and a signal cannot share a name and Flow also needs a `phase()` read (TD-ARCHITECTURE B1) |
| `gold_changed`, `tower_built`, `tower_upgraded` | TowerSim | HUD, views | Commit first, `gold_changed` then the tower signal; a refusal emits nothing |
| `hero_pinned`, `burst_started` | HeroSim | Views, HUD | After state set; handlers never issue commands |
| `attack_fired`, `damage_applied` | Combat | Combat view, audio (Alpha) | View-only; listeners never call `deliver` |
| Gesture signals | InputResolver | HeroInput, TowerInput, HudLogic | Re-entrant calls queue FIFO and drain in the outermost call |
| `latched(cause)` | Battle FatalLatch | Flow (enters `FATAL`) | Once, on the first `fatal()`, after the forward to the app latch (ADR-0001) |
| `lifecycle_paused()` | InputAdapter | `Flow.pause` | Through `view_wiring`; after the adapter's `resolver.cancel()` (ADR-0003) |
| `tapped()` | Paused `TapScreen` | `Flow.resume` | Through `view_wiring` (ADR-0003) |

Rules for all of them (ADR-0006):
1. **Commit, then emit.** State is final before the first listener runs.
2. **Gameplay does not depend on listeners.** A battle with every view listener removed produces identical state (TR-tower-012, TR-hud-004).
3. **Wiring signals** (the ones in the first six rows that the sim itself consumes, plus `latched`) are connected only in the Builder, through the battle's `Wiring.connect_recorded()`, never deferred. Every wrapper connection to a sim signal goes through the wrapper's `view_wiring`. A direct `.connect()` on a sim signal anywhere else is forbidden, and teardown undoes both records (ADR-0001).
4. **View allowlist.** A test fails if any battle signal has no listener, except signals on a named allowlist (TR-state-013).
5. Signals declare typed parameters, but GDScript does not check them at `emit()`, and a `connect` with a mismatched Callable fails only at runtime. The real guard is the listener-count test plus recording fakes that assert payloads, not only call counts (ADR-0007). The type of `tower_id` is undecided (QQ-04).

### 4. Initialisation order

```
Engine starts main scene ──► AppRoot._ready
  1. AppRoot creates its FatalLatch first. The fatal screen is FatalScreen, built in code from
     the default theme and font, loading no resource, so it always shows. AppRoot state: BOOT
  2. Catalogue.load_manifest(manifest_path, data_root)   Unloaded ─► Loading ─► Ready | Failed
       Failed ─► AppRoot keeps the LoadResult and calls the app latch's fatal() with a cause
       built from its errors ─► FatalScreen (no fallbacks, no save access)
  3. (VS) Save/Load boot, only after a Ready load: inject loaded progression
  4. AppRoot holds the Ready catalogue, reads the Input record once into PresentationSettings,
     picks stage_id and rng_seed
  5. BattleBuilder.build(catalogue, stage_id, rng_seed, app_latch.fatal)
       a. Create the battle FatalLatch first, forwarding to the app latch
       b. Create one fresh StatAccessor for this battle over the shared Catalogue, with the
          battle latch's fatal as its failure handler
       c. Read the Stage, Input and Hero records; check stage inputs;
          InputResolver.create(drag_slop, tap_slop) (null: fatal("input_record_invalid"))
       d. Construct HaltGate, TickMath, DevErrorSink, Wiring, Flow, Combat, EnemyWave,
          TowerSim, HeroSim
       e. Inject HaltGate.halted, Flow.in_build, EnemyWave.targets, InputResolver.cancel (as
          cancel_input()), left_handed, TickMath.to_ticks, DevErrorSink.report (method Callables
          only); make every signal connection through Wiring.connect_recorded()
       f. Return Battle (no node touched). The battle latch is checked after each step; once it
          is set, build returns null and AppRoot adds no wrapper
  6. AppRoot loads and instances the BattleWrapper scene (either one null: fatal("wrapper_scene_failed")).
     The wrapper builds the InputAdapter, Clock, HeroInput, TowerInput, HudLogic, HUD and views from
     battle.input_resolver and PresentationSettings; on mobile it reads FieldInsets once (ADR-0003).
     AppRoot state: IN_STAGE
  7. Flow enters Build
```

Dependency note: the stat accessor cannot be used before step 2 finishes. The resolver reads its slops directly from the Input record, not through the accessor (TR-input-012).

### 5. Retry and teardown path

```
Result screen "Retry" tapped
  ─► AppRoot.request_retry(): sets an idempotent latch and returns (frees nothing, not even its caller)
AppRoot._process, each frame, in this order:
  1. If the app latch is set: tear down (steps 3 to 6, if a battle exists), show FatalScreen,
     set FATAL, set_process(false). Stop.
  2. If the retry latch is set and Flow is WON or LOST: clear the latch, tear down, rebuild.
     A retry latch in any other phase is cleared and ignored.
  3. Stop the Clock; battle.input_resolver.cancel(); wrapper.process_mode = PROCESS_MODE_DISABLED
  4. wrapper.view_wiring.disconnect_all(); remove_child(wrapper); wrapper.queue_free()
  5. battle.unwire(): disconnect every pair in the Builder's Wiring record, then clear it
  6. Set AppRoot's battle and wrapper fields to null
  7. BattleBuilder.build(...) again with the SAME catalogue. Null: add no wrapper; next frame's
     step 1 shows Fatal. Otherwise add a new wrapper and set IN_STAGE
```
Retry resets nothing in place. It rebuilds. `remove_child()` stops the old subtree's processing and input at once; `PROCESS_MODE_DISABLED` is a second guard (the adapter runs `PROCESS_MODE_ALWAYS`, so its own guard is `_live`, set false on exit, ADR-0003). `free()` is never used on the wrapper. Because both `Wiring` records are undone, a weakref to the old `Battle` and to each sim reads null whether Godot's Callables and connections hold strong or weak references (TR-state-009, TR-enemy-008, TR-tower-013). ADR-0001 tests V1, V2 and V6 record and check this.

### 6. Pause and focus path

```
First away notification of an episode (APPLICATION_FOCUS_OUT, APPLICATION_PAUSED or
WM_WINDOW_FOCUS_OUT), or any Android back request (NOTIFICATION_WM_GO_BACK_REQUEST)
(which ones fire where: NEEDS VERIFICATION, ADR-0003 check S5)
  1. InputAdapter: resolver.cancel(); clear _down; emit lifecycle_paused()
  2. Flow.pause() (through view_wiring): remember phase, enter PAUSED, call cancel_input()
     (a no-op now), emit phase_changed(PAUSED). Idempotent; a terminal phase ignores it
  3. Wrapper: show the Paused TapScreen, close the adapter's press gate, call clear_press()
  4. Battle.tick returns at once (the in-sim gate); the Clock zeroes its accumulator (ADR-0004)
  A finger held across the pause stays dead until lifted. The resume tap is taken by the Paused
  screen and the closed gate drops its press, so it reaches nothing beneath (TR-state-010)
  Resume: Paused TapScreen.tapped ─(view_wiring)► Flow.resume(); Flow restores the remembered
  phase; the gate opens when the modal hides; walk and telegraph resume exactly (TR-hero-013)
```
A focus-in notification ends the away episode but resumes nothing; only the Paused tap resumes. On desktop the click that refocuses the window is that tap (a product choice the user confirmed). A back request pauses every time, since no focus-in follows it, and `config/quit_on_go_back=false` stops it quitting mid-battle. A viewport resize cancels input without a pause; on mobile it also reports a dev error, because insets are not re-read. Real-time models (button arming, chip window) freeze while Paused (TR-hud-007).

### 7. Fatal path

```
Any of: catalogue load failure (AppRoot) · bad accessor call (accessor) · bad stage input or
invalid Input record (Builder) · wrapper scene fails to load (AppRoot) · broken stage scene (wrapper)
  ─► fatal(cause)   (injected Callable; idempotent; keeps the FIRST cause)
       battle latch, first call: forward to the app latch, then emit latched(cause) once
         ─► Flow enters FATAL, calls cancel_input(), emits phase_changed(FATAL); later tick steps
            see halted() and return; a partial build returns null and gets no wrapper
       app latch, first call: push_error(cause) (the only latch that logs), records, emits
  AppRoot's next _process: tear down, show FatalScreen, state FATAL (absorbing; never opens saves)
  Debug builds show the cause and each ValidationError by file, record and field;
  release builds show one generic line.
```
GDScript has no exceptions, so after `fatal` every caller checks `halted()` and returns (TR-state-011). The injected `halted()` is `HaltGate.halted()`, never a Callable on `Battle`: true when Flow is WON, LOST or FATAL, or the battle FatalLatch is set. It is false while PAUSED; the tick gate, not `halted()`, stops time during a pause. `Battle.halted()` is a pass-through to the same gate for the wrapper and tests (ADR-0001).

### 8. Save/load path (Vertical Slice, reserved)

Not built at MVP. The contract MVP code must respect: progression systems own their schema, expose `to_dict()` and `from_dict()` with a `version` field, and never call Save. Save owns the file and injects loaded state at boot (step 3 above). The serialised state will be skill points, tree nodes, weapons, stars and settings. No battle state is ever saved, because a battle is rebuilt from `(catalogue, stage_id, rng_seed)`.

### 9. Dev telemetry path

Development builds only. A gesture-log harness listens to resolver signals, to TowerSim's `tower_upgraded`, and reads `chip_state()` at each tower prompt (Input Rule 13), so Tower keeps no log of its own. The harness is wrapper-side and reads Feature through the same view surface as the HUD; ADR-0008 owns it. A run log appends JSON lines to `user://run_log.jsonl` through an injectable sink. A write failure is non-fatal and release builds never write (TR-hud-013, TR-input-015). Both listen only; neither can change a result.

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

### B0. Shared types (ADR-0001 and ADR-0002 accepted; ADR-0005, ADR-0009 proposed)

| Type | Base | Owning file (proposed) | Fields or role | Decided by |
|---|---|---|---|---|
| `Catalogue` | `RefCounted` | `src/foundation/data/catalogue.gd` | Holds every record by `StringName` ID after a Ready load; read-only by contract; holds no `FatalLatch`, handler, battle or node. Interface in B1a | ADR-0002 (Accepted) |
| `LoadResult` | `RefCounted` | same | `ok: bool`, `errors: Array[ValidationError]` (read-only), `catalogue: Catalogue` (null unless `ok`) | ADR-0002 (Accepted) |
| `ValidationError` | `RefCounted` | `src/foundation/data/validation_error.gd` | `code: StringName`, `source: String`, `record_id: StringName`, `field: StringName` (a path such as `levels[1].splash_radius`), `detail: String` (display only; tests compare the first four, never `detail`) | ADR-0002 (Accepted) |
| Record classes: `TowerRecord`, `EnemyRecord`, `WaveRecord`, `StageRecord`, `HeroRecord`, `BurstRecord`, `InputRecord`, plus `TowerLevel`, `WaveGroup`, `PinShape` | `RefCounted` | `src/foundation/data/records/` | `id: StringName` plus each GDD's fields, one typed `var` per `schema.gd` entry. Lists are typed `Array` (not packed), made read-only after validation. A record holds the IDs it references, never the record. `StageRecord` holds `path_points`, `slot_positions`, `path_width`, `requires_bend`, `early_call_seconds_per_gold`, `hero_start`, `pin_rect`, `pin_exclusion: Array[PinShape]`, `scene_ref`, `wave_ids`, `starting_gold`, `starting_lives`. `InputRecord` holds `drag_slop`, `tap_slop`, `edge_reject_margin`, `left_handed`, `reduce_motion` | ADR-0002 (Accepted) |
| `CatalogueSnapshot` | `RefCounted` | `src/foundation/data/` (file name proposed) | `take(catalogue) -> Dictionary` walks every record through the schema into fresh plain values; `diff(before, after) -> Array[String]` returns each differing path. Replaces `duplicate_deep()`, which copies no `RefCounted` fields | ADR-0002 (Accepted) |
| `ReadContext` | `RefCounted` | `src/foundation/data/read_context.gd` | `def_id: StringName`, `level: int = 0`, `live_entity: Object = null`. **One reused instance per caller** (per enemy, per tower slot, one for the hero), never one per read, so a tick allocates nothing | ADR-0005 |
| `Targetable` | `RefCounted` | `src/core/combat/targetable.gd` | `spawn_id: int`, `position: Vector2` (cached once per tick), `removed: bool`, `health: Health`, `status: Status` | ADR-0009 |
| `Enemy` | `Targetable` | `src/feature/enemy_wave/enemy.gd` | Adds `def_id: StringName`, `distance: float`, its `ReadContext` | ADR-0009 |
| `DamageEvent` | `RefCounted` | `src/core/combat/damage_event.gd` | `target: Targetable`, `amount: float`, `source_kind: Combat.SourceKind`, `source_id: StringName` | ADR-0009 |
| `StageResult` | `RefCounted` | `src/core/flow/stage_result.gd` | `outcome: Flow.Phase` (WON, LOST or FATAL), `last_wave_started: int`, `lives_left: int`, per-source damage copied from Combat | ADR-0006 |
| `Battle` | `RefCounted` | `src/root/battle.gd` | Read-only members: `flow: Flow`, `combat: Combat`, `enemy_wave: EnemyWave`, `tower_sim: TowerSim`, `hero_sim: HeroSim`, `fatal_latch: FatalLatch`, `input_resolver: InputResolver`. Private strong members, held so every injected Callable keeps a live target: `_halt_gate: HaltGate`, `_tick_math: TickMath`, `_dev_error_sink: DevErrorSink`, `_stat_accessor: StatAccessor` (one per battle), `_wiring: Wiring` | ADR-0001 (Accepted) |

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
## Built on Catalogue.type_of() and tower(id).levels.size() (ADR-0002).
func is_tower(id: StringName) -> bool
func level_count(def_id: StringName) -> int
```
Invariants: a bad call (unknown or inapplicable key, wrong type, bad level, unresolved `def_id`) calls the injected failure handler, which survives release builds, so it is not an `assert`. After a bad call the method returns `0` or `0.0` and the caller must check `halted()` before using it. Two typed methods replace version 1's `Variant` return, so callers keep static typing (TD-ARCHITECTURE A9). The Builder creates one accessor per battle over the shared catalogue, with the battle latch's `fatal` as its failure handler (ADR-0001).

### B1a. Catalogue (ADR-0002, Accepted)

```gdscript
class_name Catalogue extends RefCounted
const DATA_ROOT := "res://assets/data/catalogue/"
## Reads bytes, then calls from_texts. The only FileAccess user. Not named `load`,
## which would shadow the global load().
static func load_manifest(manifest_path: String, data_root: String = DATA_ROOT) -> LoadResult
## Tier 0a with no I/O. file_texts maps path -> text.
static func from_texts(manifest_text: String, file_texts: Dictionary, data_root: String = DATA_ROOT) -> LoadResult
## Tier 0b and Tiers 1 to 4. docs are {source, type, records}.
static func from_documents(docs: Array[Dictionary]) -> LoadResult

## Typed lookups. Null for an ID not of that type; never call a handler.
func tower(id: StringName) -> TowerRecord
func enemy(id: StringName) -> EnemyRecord
func wave(id: StringName) -> WaveRecord
func stage(id: StringName) -> StageRecord
func hero(id: StringName) -> HeroRecord
func burst(id: StringName) -> BurstRecord
## All records of a type, in manifest order. Read-only.
func towers() -> Array[TowerRecord]
func enemies() -> Array[EnemyRecord]
func waves() -> Array[WaveRecord]
func stages() -> Array[StageRecord]
func heroes() -> Array[HeroRecord]      # exactly one (Tier 0b)
func bursts() -> Array[BurstRecord]
func inputs() -> Array[InputRecord]     # exactly one (Tier 0b)
func type_of(id: StringName) -> StringName   # &"" when unknown
```
Invariants: data is UTF-8 JSON under the data root, listed in `manifest.json`, read with `FileAccess` and parsed with a `JSON` instance; never `.tres`, `load()` or `ResourceLoader`, and no `DirAccess` in runtime code. Load is synchronous, once, from AppRoot `_ready()`. Tiers 0a and 0b stop on an error; Tiers 1 to 4 collect all, one error per field. Logic tests build catalogues through `from_texts` or `from_documents`. The CI content test holds each owning GDD's rules, each proved on a broken fixture.

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
class_name InputAdapter extends Node      # process_mode = PROCESS_MODE_ALWAYS
const MOUSE_POINTER := 1 << 16            # no touch index reaches it
## Once per away episode, and on each back request, after resolver.cancel().
## The wrapper connects it to Flow.pause through view_wiring.
signal lifecycle_paused()
## Built by BattleWrapper only.
func setup(resolver: InputResolver, edge_reject_margin: float, insets: FieldInsets, dev_error: Callable) -> void
## Closed while a modal TapScreen shows. Drops presses only.
func set_presses_blocked(blocked: bool) -> void
# Contract: presses from _unhandled_input; moves, releases and cancels from _input, only for
# pointers in _down. Every forwarded press is followed by exactly one release, cancel_pointer
# or cancel() for that index, even when a Control with mouse_filter = STOP lies under the drag.
# Drops events with device == InputEvent.DEVICE_ID_EMULATION; never tests device == 0.
# Calls resolver.cancel() on away notifications, the back request and viewport resize.
# Silent once _live is false (set on NOTIFICATION_EXIT_TREE).

class_name FieldInsets extends RefCounted   # read-only by contract; field units
var top: float
var bottom: float
var left: float
var right: float

class_name SafeAreaMath extends RefCounted
static func field_insets(safe_px: Rect2i, window_px: Rect2i, field: Vector2) -> FieldInsets
## dp per field unit under keep; the guard needs >= 2.0 / 3.0.
static func dp_per_unit(window_px: Vector2i, field: Vector2, dpi: float) -> float
static func is_rejected(pos: Vector2, field: Vector2, edge_reject_margin: float, insets: FieldInsets) -> bool

class_name TapScreen extends Control      # MOUSE_FILTER_STOP, FOCUS_NONE, mouse family only
## Fires on the release of a press this screen saw; then clears every held press.
signal tapped()
func clear_press() -> void
```
Display (ADR-0003 Decision 1): `project.godot` sets every display, window and pointing key explicitly: `canvas_items` + `keep` at 540x960, portrait, `emulate_touch_from_mouse=false`, `emulate_mouse_from_touch=true`, `quit_on_go_back=false`. Taller phones letterbox. The minimum size guard needs at least 360 x 640 dp effective scale; it logs and never blocks. Insets are read once per battle, on mobile only; desktop insets are 0. The Mobile Platform GDD (Vertical Slice) inherits all of this rather than blocking it (TD-ARCHITECTURE A3).

Product defaults the user confirmed on 2026-11-04 (ADR-0003 Decision 5): (1) letterbox at MVP, reviewed before Vertical Slice; (2) a notification-shade pull pauses; (3) on desktop the click that refocuses the window resumes (if that feels wrong, `TapScreen` ignores the first press after a desktop focus-in); (4) insets are not re-read, and a mid-battle resize on mobile logs a dev error; (5) Android back pauses instead of quitting mid-battle.

Behaviour behind these contracts (event order, `is_canceled()`, emulation, notifications, safe-area units, setting names) is **NEEDS VERIFICATION** until ADR-0003's spike runs. S0a (desktop) and S0b (device) record PASS or FAIL per check in ADR-0003's "Spike results" section and in `docs/engine-reference/godot/modules/input.md`. A story that rests on an unverified check waits for that check or its fallback (ADR-0003 Guideline 15).

### B4. Battle and Builder (ADR-0001, ADR-0004)

```gdscript
class_name Battle extends RefCounted
var input_resolver: InputResolver # read-only; the wrapper builds the adapter from it
func tick(dt: float) -> void      # the ONLY way simulation time advances.
                                  # Returns at once unless flow.phase() is WAVE or INTERMISSION
                                  # and halted() is false. Gate and order: ADR-0004.
func halted() -> bool             # pass-through to HaltGate, for the wrapper and tests
## Disconnects every Builder connection. Idempotent. Composition root only.
func unwire() -> void

class_name HaltGate extends RefCounted
## True on WON, LOST or FATAL, or when the battle latch is set. False while PAUSED.
func halted() -> bool

class_name BattleBuilder extends RefCounted
## Returns null when a fatal fired during the build. Touches no node.
static func build(catalogue: Catalogue, stage_id: StringName, rng_seed: int, fatal_handler: Callable) -> Battle
```
Invariants: `build` touches no node, so bots and tests call it headless. The parameter is `rng_seed`, so it does not shadow the global `seed()`. It creates the battle FatalLatch first, checks it after each step and returns `null` once it is set, and makes every connection in one function through the battle's `Wiring`. It is never called from inside a signal. Injected callables are method Callables on objects that `Battle` or `AppRoot` holds: no lambda, and no `bind()` with a sim argument. No sim object holds a reference to `Battle`, `AppRoot` or any `Node`, and `Battle.unwire()` undoes every connection at teardown, so dropping the `Battle` frees everything and the weakref test passes whichever way Callable references work (ADR-0001). Gameplay classes never read `Engine`, `Time`, `OS`, a timer or `await`.

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
signal phase_changed(value: Phase)   # GDD name: phase. Renamed (TD-ARCHITECTURE B1)
signal lives_changed(current: int)
signal wave_called_early(seconds_left: float)
```
Outcome commit order (Rule 15): set state, then the tick gate stops time, then `cancel_input()`, then emit `phase_changed`. FATAL is a `Phase` value because Rule 15 has `phase` name Won, Lost, Paused and Fatal, and Tower's chip listens for Fatal. AppRoot's own states (Boot, InStage, Fatal) are separate and live on AppRoot. Retry is an AppRoot latch, not a Flow command.

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
func wave_index() -> int                    # view-only: 1-based last wave started, 0 before the first start,
                                            # set when start_next_wave commits, unchanged by a clear or outcome (Rule 14)
func got_through_by_type() -> Dictionary    # view-only, never reset per wave (Rule 14)
signal enemy_leaked(lives_cost: int)
signal enemy_killed(bounty: int)
signal wave_cleared(intermission_duration: float)
signal waves_complete()                     # breaks the past-tense rule: QQ-07
```
The enemy stays a valid reference after removal (`removed` is set, the object is not freed). Lists are built as `Array[Targetable]` from the start, since typed arrays are invariant.

### B8. TowerSim and HeroSim commands (ADR-0010)

```gdscript
class_name TowerSim extends RefCounted
enum BuildResult { OK, HALTED, BAD_SLOT, BAD_TOWER, SLOT_OCCUPIED, NO_GOLD }
enum UpgradeResult { OK, HALTED, BAD_SLOT, NO_TOWER, MAX_LEVEL, NO_GOLD }
func build(slot_index: int, tower_id: StringName) -> BuildResult
func upgrade(slot_index: int) -> UpgradeResult
func gold() -> int
func slot_state() -> Array                  # per slot: tower_id, level, cooldown_left
func chip_state() -> Dictionary             # view-only read (Tower Rule 17)
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

### B9. Injected values and callables (ADR-0001, Accepted)

| Name | Injected into | Meaning |
|---|---|---|
| `halted() -> bool` | EnemyWave, TowerSim, HeroSim, HudLogic | `HaltGate.halted()`, never a Callable on `Battle`. Checked after every accessor read and every signal. |
| `in_build() -> bool` | HeroSim, HeroInput, HudLogic | `Flow.in_build`: true while Flow is in BUILD. |
| `targets() -> Array[Targetable]` | TowerSim, HeroSim | EnemyWave's `targets()`, so Tower and Hero never reference EnemyWave (Tower Rules 9, 13; Hero Rule 4). |
| `cancel_input() -> void` | Flow | `InputResolver.cancel`, so Flow never references the resolver (TR-state-007). Headless, a no-op. `cancel()` has three callers: the adapter (away, back, resize), Flow through `cancel_input()` (Won, Lost, Paused, Fatal) and AppRoot at teardown (QQ-20). |
| `left_handed: bool` | HeroSim | From the Input record, fixed per battle (Hero Rule 2, TR-hero-004). Passed by the Builder with the Hero record ID and `burst_id`. |
| `PresentationSettings` | HeroInput, HudLogic, every view | `left_handed` and `reduce_motion`, read once from the Input record by AppRoot and passed by the wrapper. Views read Reduce Motion only from here (QQ-09). |
| `fatal(cause: String) -> void` | Builder, accessor, all sims | The battle FatalLatch's `fatal`. Its first call forwards to the AppRoot FatalLatch, then emits `latched`. Idempotent. |
| `dev_error(msg: String) -> void` | EnemyWave, Flow, `Wiring`, others | `DevErrorSink.report`: `push_error` in every build, never halts. Tests replace it with a recording fake. |
| `to_ticks(seconds: float) -> int` | Combat, EnemyWave, TowerSim, HeroSim, Flow, HudLogic | `TickMath.to_ticks`. Rounds half away from zero; `dt` fixed at build. HudLogic uses it for the burst wedge. |
| `wave_index() -> int` | Flow | EnemyWave's `wave_index()`, for the result's last wave started, so Flow keeps no wave count (Flow Rule 15, TR-enemy-016). |
| `burst_id: StringName` | HeroSim, HudLogic | The Hero record's `burst_id`. HudLogic reads Burst `cooldown` through the accessor with it for the wedge (HUD Rule 12). |

All are method Callables, or plain values, on objects that `Battle` or `AppRoot` holds (B4 rule; ADR-0001 Guideline 5).

### B10. HUD read surface (ADR-0006, ADR-0010)

The HUD reads, never writes: `Flow.phase()`, `lives()`, `intermission_left`, `result()`; `TowerSim.gold()`, `slot_state()`, `chip_state()`; `HeroSim` queries and `cooldown_left`; `EnemyWave.wave_index()`, `got_through_by_type()`; `Combat.hero_share()` for the end-of-stage log. It also listens to TowerInput's `tower_inspected` signal. Every read is defined in its owner's GDD (Enemy & Wave Rule 14, Tower Rule 17, Hero Rule 16). There is no cooldown total on Hero: the wedge is `cooldown_left() / to_ticks(cooldown)`, clamped to 1, with Burst `cooldown` read through the accessor at use time (HUD Rule 12). The pips and "Broke on wave N" use `wave_index()`. `burst_button_centre()` is owned by the HUD and read once by HeroInput at registration.

### What cannot be tested headless

These run only in the editor or on a device. ADR-0007 lists them as manual-evidence stories in `production/qa/evidence/`: the InputAdapter and Control event order, lifecycle notifications, safe-area values and display density (ADR-0003 spike S0a and S0b); `push_error` output in a release export (ADR-0001 V8); the catalogue load from an Android export (ADR-0002 X2); draw-call and frame-time budgets. Everything in B0 to B2 and B4 to B9 runs headless, including the weakref test, provided the test itself holds no reference to the old battle. The teardown order on retry (no callback reaches a removed wrapper) runs headless too, as a scene-tree integration test (ADR-0001 V6). The adapter's logic and `SafeAreaMath` run headless through a test-only entry (ADR-0003 A1 to A11).

## ADR Audit

### ADR Quality Check

Three ADRs exist, all Accepted by the user on 2026-11-04: ADR-0001, ADR-0002 and ADR-0003. Each has an Engine Compatibility table pinned to 4.7.2, lists its post-cutoff and unverified APIs, maps its GDD requirements, and passed a TD-ADR and a godot-specialist review (both CONCERNS, all findings applied). Version 4 of this document applies each ADR's architecture.md sync list. Engine facts each ADR leaves open are tracked by named tests: ADR-0001 V1, V6 and V8; ADR-0002 E1 to E3, X1 and X2; ADR-0003 spike S0a and S0b. The next `/architecture-review` performs the full check across all three, and again once ADR-0004 to ADR-0011 exist.

### Traceability Coverage Check

Technical Requirements Baseline: **121 requirements from 8 GDDs, 121 registered, 0 provisional** (TR registry version 4, 121 entries, all `active`; TR-input-016 and TR-hud-002 reworded 2026-11-04 to match ADR-0003). No GDD contributed zero requirements. The full per-requirement matrix is `docs/architecture/requirements-traceability.md`; the latest review is `docs/architecture/architecture-review-2026-11-03b.md`. Both still show the version 3 counts until the next `/architecture-review` updates them.

| Status | Count |
|---|---|
| Covered by an Accepted ADR (in full) | 31 |
| Covered by a Proposed ADR | 0 (no proposed ADR is written yet) |
| Partial (an Accepted ADR covers part; the rest has a named owner) | 5 |
| **Gap** | **85** |

Each requirement is counted once. The five partial requirements and who owns the rest:

| TR | Covered now | Rest owned by |
|---|---|---|
| TR-data-003 | ADR-0002: manifest, no `DirAccess`, export include filter, desktop pack smoke test (X1) | ADR-0002 X2: the Android export proof, on a device, at Technical Setup |
| TR-data-015 | ADR-0002: one small synchronous load, no import step, no scene at boot | ADR-0002 P1 and P2: device timings at the first phone build (QQ-11) |
| TR-input-006 | ADR-0003: `edge_reject_margin` and safe-area insets in field units | Mobile Platform GDD: Android gesture insets (QQ-21) |
| TR-input-013 | ADR-0003: HUD Controls consume presses before the adapter; the press gate | ADR-0008: burst button, build arc and world targets as resolver discs |
| TR-state-010 | ADR-0003: focus loss enters Paused, input cancels, the resume tap reaches nothing | ADR-0004: ticks stop at the tick gate; the Clock zeroes its accumulator |

By GDD: data-config 15, input 16, game-state 14, combat 14, enemy-wave 16, tower 15, hero 15, battle-hud 16. By layer tag: 53 Foundation, 45 Core, 3 Feature, 20 Presentation. By engine risk: 14 HIGH, 31 MEDIUM, 76 LOW.

The per-ADR coverage in the next section assigns every one of the 121 requirements to one primary ADR, so no requirement is left without a planned decision. Two requirements are split across two ADRs (TR-state-010, TR-input-013); each is counted once, under its primary ADR, and the second ADR lists it as shared with the part it covers.

## Required ADRs

Eleven ADRs close all 121 gaps. ADR-0001 to ADR-0003 are Accepted, with those numbers. The other numbers are proposed, in dependency order, and `/architecture-decision` assigns the final ones. The review used labels P01 to P15; the column maps them. Version 1 proposed 15. To cut scope for a solo part-time developer (LP-FEASIBILITY 13), four pairs were folded: Fatal Path into App Lifecycle, Determinism into the Tick ADR, Combat API into the Enemy Entity ADR, and Dev Telemetry into the command and resolver ADRs. Input Resolver moved to Foundation to match its module. TR-hero-012 (bot equivalence) moved to ADR-0010 because it needs the command enums.

| ID | Title | Status | Layer | Depends on | Review label | TRs | Engine risk |
|---|---|---|---|---|---|---|---|
| ADR-0001 | App Lifecycle, Composition Root and Fatal Path | Accepted 2026-11-04 | Foundation | none | P01, P06 | 15 | HIGH |
| ADR-0002 | Catalogue Storage Format, Manifest and Validation | Accepted 2026-11-04 | Foundation | ADR-0001 | P03 | 10 | HIGH |
| ADR-0003 | Input Adapter, Display Stretch and Platform Lifecycle | Accepted 2026-11-04 | Foundation | ADR-0001 | P05 | 11 | HIGH |
| ADR-0004 | Fixed-Tick Clock, Tick Order, Frame Order and Determinism | Proposed | Foundation | ADR-0001, ADR-0003 | P02, P07 | 20 (+1 shared) | HIGH |
| ADR-0005 | Stat Accessor and Read-Context Contract | Proposed | Foundation | ADR-0002, ADR-0001 | P04 | 6 | LOW |
| ADR-0006 | Battle Signal Contracts and View Allowlist | Proposed | Foundation | ADR-0001, ADR-0004 | P10 | 10 | MEDIUM |
| ADR-0007 | Headless Test Harness, gdUnit4 and Layer Lint | Proposed | Foundation | ADR-0001, ADR-0006 | P08 | 6 | MEDIUM |
| ADR-0008 | Input Resolver Core and Signal Contract | Proposed | Foundation | ADR-0003, ADR-0006 | P09, part of P15 | 11 (+1 shared) | MEDIUM |
| ADR-0009 | Enemy Entity, Roster and Combat API | Proposed | Core | ADR-0001, ADR-0005 | P11, P12 | 17 | MEDIUM |
| ADR-0010 | Sim/Input Split, Command Result Codes and Dev Telemetry | Proposed | Core | ADR-0004, ADR-0008, ADR-0009 | P13, part of P15 | 10 | LOW |
| ADR-0011 | Battle Field Rendering and Draw-Call Budget | Proposed | Presentation | ADR-0009, ADR-0010 | P14 | 5 | MEDIUM |

The TRs column sums to 121. "+1 shared" marks a requirement whose primary ADR is ADR-0003; it is not counted again.

### What each ADR decides and which requirements it covers

**ADR-0001 App Lifecycle, Composition Root and Fatal Path** (Foundation, **Accepted** 2026-11-04). Decided: no autoloads; AppRoot as the main scene with states `BOOT`, `IN_STAGE`, `FATAL`; a scene-free static `BattleBuilder.build(catalogue, stage_id, rng_seed, fatal_handler)` that returns null on a fatal during build; `Battle` holding every Callable target; `HaltGate`; method Callables only; two `Wiring` records undone at teardown; one `FatalLatch` class with a battle and an app instance; `DevErrorSink`; push_error, never assert; retry by latch, then teardown in a fixed order (`remove_child` then `queue_free`, then `unwire()`) and rebuild, with the weakref proof; a code-built `FatalScreen`; Reduce Motion through `PresentationSettings`.
Covers (15): TR-data-004, TR-data-006, TR-data-009, TR-data-011, TR-input-012, TR-state-001, TR-state-002, TR-state-009, TR-state-011, TR-enemy-005, TR-enemy-012, TR-tower-006, TR-tower-013, TR-hero-004, TR-hud-006.

**ADR-0002 Catalogue Storage Format, Manifest and Validation** (Foundation, **Accepted** 2026-11-04). Decided: JSON files read with `FileAccess` and a `JSON` instance; an explicit `manifest.json`; one schema table per record type driving the parser, validator and snapshot; typed `RefCounted` records with read-only lists; `load_manifest`, `from_texts` and `from_documents`; a tiered validator; a schema-walk `CatalogueSnapshot` in place of `duplicate_deep()`; a CI content test with one broken-fixture test per rule; export filters and a desktop pack smoke test.
Covers (10): TR-data-001, TR-data-002, TR-data-003 (partial: Android proof X2 owed), TR-data-005, TR-data-007, TR-data-013, TR-data-015 (partial: device timings owed), TR-enemy-001, TR-hero-014, TR-hud-016.

**ADR-0003 Input Adapter, Display Stretch and Platform Lifecycle** (Foundation, **Accepted** 2026-11-04). Decided: explicit `canvas_items` + `keep` letterbox at a 540x960 viewport; a 360 x 640 dp minimum size guard; no Camera2D; an `InputAdapter` that reads presses in `_unhandled_input` and endings in `_input`, drops emulated pointer events and has a modal press gate; a mouse-only `TapScreen` for modals; a union of lifecycle notifications plus the Android back request as a pause; safe-area insets read once per battle on mobile through `SafeAreaMath`; a two-part spike (S0a desktop, S0b device) whose checks gate the stories that rest on them. The Mobile Platform GDD inherits it.
Covers (11): TR-input-002, TR-input-003, TR-input-004, TR-input-005, TR-input-006 (partial: gesture insets go to the Mobile Platform GDD, QQ-21), TR-input-013 (partial: the disc part is ADR-0008's), TR-input-016, TR-state-010 (partial: the tick gate and accumulator are ADR-0004's), TR-hud-002, TR-hud-003, TR-hud-014.

**ADR-0004 Fixed-Tick Clock, Tick Order, Frame Order and Determinism** (Foundation). Decides: tick driver and rate, clamp value and max ticks per frame, the one tick order, commands between ticks, the in-sim clock gate, real-time presentation clocks, seeded RNG and cosmetic RNG split, float policy and per-architecture baselines, frame budget split.
Covers (20): TR-state-003, TR-state-004, TR-state-005, TR-state-006, TR-state-007, TR-state-012, TR-state-014, TR-combat-009, TR-combat-014, TR-enemy-002, TR-enemy-003, TR-enemy-007, TR-tower-005, TR-tower-010, TR-hero-003, TR-hero-006, TR-hero-011, TR-hero-013, TR-hud-005, TR-hud-007.
Shared, not counted in the 20: TR-state-010, the part where ticks stop and the Clock zeroes its accumulator on Paused. ADR-0003 covers the rest (focus loss enters Paused, input cancels, the resume tap reaches nothing).

**ADR-0005 Stat Accessor and Read-Context Contract** (Foundation). Decides: stat_int and stat_float, ReadContext reuse per caller, key vocabulary and types, non-fatal lookups.
Covers (6): TR-data-008, TR-data-010, TR-enemy-006, TR-tower-003, TR-hero-005, TR-hud-011.

**ADR-0006 Battle Signal Contracts and View Allowlist** (Foundation). Decides: synchronous emit, commit before emit, final signal names (QQ-07) and payloads, ID types, view allowlist.
Covers (10): TR-data-014, TR-state-008, TR-combat-010, TR-enemy-004, TR-tower-004, TR-tower-012, TR-hero-008, TR-hud-004, TR-hud-010, TR-hud-012.

**ADR-0007 Headless Test Harness, gdUnit4 and Layer Lint** (Foundation). Decides: fixtures, recording fakes that assert payloads, listener-count test, push_error reporting, layer-import lint, the manual-evidence list for what cannot run headless, GDScript 4.7 pitfalls for the control manifest.
Covers (6): TR-data-012, TR-input-014, TR-state-013, TR-combat-012, TR-enemy-014, TR-tower-014.

**ADR-0008 Input Resolver Core and Signal Contract** (Foundation). Decides: pure resolver, hit-target registry, state machine, re-entrancy queue, payloads, gesture log.
Covers (11): TR-input-001, TR-input-007, TR-input-008, TR-input-009, TR-input-010, TR-input-011, TR-input-015, TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009.
Shared, not counted in the 11: TR-input-013, the part where the burst button, build arc and world targets are resolver discs, not Controls. ADR-0003 covers the rest (HUD Controls consume presses before the adapter).

**ADR-0009 Enemy Entity, Roster and Combat API** (Core). Decides: Targetable base class, Health and Status attachment, roster ownership and typed lists, path lookup, view-only reads (`wave_index()`, `got_through_by_type()`), deliver guards, targeting helpers, per-tick budget.
Covers (17): TR-combat-001, TR-combat-002, TR-combat-003, TR-combat-004, TR-combat-005, TR-combat-006, TR-combat-007, TR-combat-008, TR-combat-013, TR-enemy-008, TR-enemy-009, TR-enemy-010, TR-enemy-011, TR-enemy-013, TR-enemy-016, TR-tower-007, TR-hero-007.

**ADR-0010 Sim/Input Split, Command Result Codes and Dev Telemetry** (Core). Decides: HeroSim/TowerSim vs HeroInput/TowerInput, result enums with OK = 0, gold ownership, bot equivalence, run counters and run log.
Covers (10): TR-tower-001, TR-tower-002, TR-tower-008, TR-tower-009, TR-hero-001, TR-hero-002, TR-hero-009, TR-hero-012, TR-hero-015, TR-hud-013.

**ADR-0011 Battle Field Rendering and Draw-Call Budget** (Presentation). Decides: single _draw nodes, pools, draw order, path polygon, HUD draw budget, hit-flash shader question.
Covers (5): TR-combat-011, TR-enemy-015, TR-tower-015, TR-hud-001, TR-hud-015.

### Priority

**Must have before any code is written (Foundation, 8):** ADR-0001 to ADR-0008. ADR-0001 to ADR-0003 are Accepted; ADR-0004 to ADR-0008 remain. ADR-0003's spike has not run: S0a (desktop, two sessions at most) comes first, S0b (device) at the first phone build. ADR-0004 and ADR-0008 rely on what it finds, so treat it as real work, not paperwork.

**Must have before the named system's first story (Core, 2):** ADR-0009 before any Combat or Enemy & Wave story (the Combat GDD names the enemy object kind and Health/Status attachment as a prerequisite). ADR-0010 before any Hero or Tower story (HeroInput and TowerInput placement).

**Can defer (Presentation, 1):** ADR-0011, to the first phone build, when draw calls are first measured.

### Decisions made in this document that need no separate ADR

These follow directly from the GDDs and the gate reviews, and the ADRs above cite them: no autoloads; simulation classes extend `RefCounted`; presentation never feeds the sim; commands run between ticks; the tick gate lives inside `Battle.tick`; `Targetable` is a Core base class; result enums put `OK = 0` first; progression systems own their save schema; code root `src/` with one folder per layer.

## Architecture Principles

1. **The battle is a plain function of its inputs.** `(catalogue, stage_id, rng_seed, command script)` determines the result. The sim runs headless, with no scene, no clock and no engine event. Bots, tests and the phone build run the same code. Everything else in this document follows from that.
2. **No globals, no autoloads.** The App Root holds the catalogue. The Builder injects it, plus `halted()`, `fatal()`, `targets()`, `cancel_input()`, the error sink and `to_ticks`, into whoever needs them. Dependency injection over singletons is a coding standard, and it is what makes each system unit-testable.
3. **Data drives gameplay, read at use time.** No gameplay number lives in code. Every value a modifier could ever touch goes through the one stat accessor and is never cached, so the Vertical Slice stat resolver drops in without call-site changes.
4. **Commit, then emit; observe, never steer.** State is final before any signal. Views and logs listen but cannot change a result, and a battle with all of them removed is identical.
5. **Fail loudly, once, and everywhere the same way.** No fallbacks in any build. One idempotent fatal path. Checks that matter in release use injected handlers and `push_error`, never `assert`, because exports strip it.
6. **Verify post-cutoff engine behaviour before building on it.** Touch input, stretch, lifecycle, safe area and Control event order are unverified in the pinned reference. The ADR that depends on one verifies it against live 4.7 docs or a device first, then records the result in the engine reference.

## Open Questions

| ID | Question | Priority | Resolved by |
|---|---|---|---|
| QQ-01 | Tick driver: custom accumulator in `_process` or `_physics_process`; tick rate (60 Hz proposed); `MAX_TICKS_PER_FRAME`; behaviour on a frame stall. | High | ADR-0004 |
| QQ-02 | **Resolved** by ADR-0003 (Accepted 2026-11-04). Stretch mode and aspect: `canvas_items` + `keep` at a 540x960 viewport, set explicitly in `project.godot`. Minimum size: 360 x 640 dp effective scale, a guard that logs. Taller phones letterbox; revealing the off-field entry needs a superseding ADR (reviewed before Vertical Slice). The Mobile Platform GDD inherits. Setting names wait on spike check S9. | High | ADR-0003 |
| QQ-03 | **Resolved** by ADR-0002 (Accepted 2026-11-04), except the Android proof. JSON read with `FileAccess`; `field_missing`, `fractional_int` and `unknown_property` caught by the schema-driven validator; read-only containers plus a schema-walk snapshot, not `duplicate_deep()`. **Still open:** proof that the catalogue loads from an Android export (X2, on a device at Technical Setup). | High | ADR-0002 (X2) |
| QQ-04 | Type of `tower_id` and other IDs across signals: `StringName`, `String` or `int`. | Medium | ADR-0006 |
| QQ-05 | `Vector2` is documented as 32-bit in a stock build but unverified on 4.7. PinGeometry avoids `Vector2` methods until it is. Float results may differ between x86 and ARM, so bot baselines are kept per architecture. | Medium | ADR-0004 |
| QQ-06 | **Resolved pending S0** by ADR-0003 (Accepted 2026-11-04). Presses are read after GUI in `_unhandled_input`; endings of forwarded pointers before GUI in `_input`; the adapter listens to a union of lifecycle notifications plus the back request; a stale ending after a `cancel()` reaches the resolver in Idle and is dropped. Each part holds only once its spike check passes (S1, S3, S4, S5), or its fallback is in place. | High | ADR-0003 (spike S0a, S0b) |
| QQ-07 | Signal names that still break the past-tense naming rule: `tap`, `ground_tap`, `pressed`, `idle` (Input GDD) and `waves_complete` (Enemy & Wave GDD). `phase` is already renamed `phase_changed` here. Rename (for example `tapped`, `ground_tapped`, `became_idle`, `waves_completed`) or record an exception, before ADR-0008 and before any test uses them, and update the GDDs to match. | Medium | ADR-0006, ADR-0008 |
| QQ-08 | Technical-director acceptance of four changes the GDDs make to earlier notes: composition root as a scene-free builder; ProjectileSpawner cut; the one tick order; path and slots moved from the stage scene to the Stage record. The TD-ARCHITECTURE review judged all four sound on technical merit; acceptance is recorded only when the ADRs are Accepted, on the user's confirmation. **Composition-root part accepted** by the user on 2026-11-04 with ADR-0001. The other three parts still wait for ADR-0004 and ADR-0009. | High | ADR-0001 (done), ADR-0004, ADR-0009 |
| QQ-09 | **Resolved** by ADR-0001 (Accepted 2026-11-04). At MVP Reduce Motion lives in the Input record. AppRoot reads it once into `PresentationSettings`, and views read it only from there, never from the catalogue. At Alpha, Settings becomes the source and no view changes. | Low | ADR-0001 |
| QQ-10 | Art bible §8 budgets a hit-flash shader; the Combat GDD uses none. | Low | technical-artist, ADR-0011 |
| QQ-11 | Unmeasured budgets: the frame split in Data Flow 10, 60 draw calls, 256 MB, about 400 range checks under 2 ms per tick, catalogue load at most 1000 ms median on an Adreno 5xx-class device. All need a device run at the first phone build. | Medium | ADR-0004, ADR-0011, performance-analyst |
| QQ-12 | No Mobile Platform & Performance GDD yet. A large top inset collides the HUD band with the arc's top panel and prompt. **Narrowed** by ADR-0003's letterbox: on a tall phone the notch and gesture bar usually sit in the bars, so in-field insets are often 0. The collision remains possible only where a safe-area inset reaches past the letterbox bar into the field. | Medium | Mobile Platform GDD |
| QQ-13 | `tests/README.md` is stale: gdUnit4 is now in `addons/` and the class cache is tracked in git. Whether the CI test command needs a prior `--import` step on a fresh clone. | Low | ADR-0007, `/test-setup` |
| QQ-14 | Stage tooling: a converter or editor for point-list stages before about 20 stages exist. | Low | tools-programmer, after MVP |
| QQ-15 | GDScript 4.7 pitfalls have no rule yet: a typed-method override needs an explicit `return`; packed-array element writes skip setters; lambdas capture locals by value; signal parameter types are not checked at `emit()`. Turn them into Required and Forbidden rules. | Medium | ADR-0007, `/create-control-manifest` |
| QQ-16 | Every `class_name` is global. Short names (`Flow`, `Combat`, `Battle`, `Catalogue`, `Clock`) risk collisions with engine or addon classes. Prefix them or lint for collisions. | Low | ADR-0007 |
| QQ-17 | Does a method `Callable` hold a strong reference to its object on 4.7? The retry weakref test depends on the answer. **Design part resolved** by ADR-0001 (Accepted 2026-11-04): every Callable target is held by `Battle` or `AppRoot`, and both `Wiring` records are undone at teardown, so the design holds either way. **Still open:** the engine fact itself, which ADR-0001 test V1 records into `docs/engine-reference/godot/` with date and version. | Medium | ADR-0001 (V1) |
| QQ-18 | Flow's command method names and their result enums (`start_wave`, `call_early`, `StartResult`, `CallResult`) are proposed here; the Game State GDD names the actions but not the methods. | Low | ADR-0010 |
| QQ-19 | An Input record with `tap_slop > drag_slop` passes the catalogue, and the resolver's `create()` then returns null with no Fatal route (cross-GDD warning C1). Check it in the catalogue validator or content test, or route a null resolver to Fatal in the builder. **Resolved**, both halves. Builder part (ADR-0001): a null resolver calls `fatal("input_record_invalid")`, so a device reaches the fatal screen. Catalogue part (ADR-0002): the boot validator does not check the rule, as the Data GDD asks; the CI content test (`content_rules_input.gd`) fails it. | Medium | ADR-0001, ADR-0002 |
| QQ-20 | **Resolved** by ADR-0001 (Accepted 2026-11-04). `cancel()` has three callers: the adapter (away, back request, resize; ADR-0003), Flow through the injected `cancel_input()` (Won, Lost, Paused, Fatal) and AppRoot at teardown (retry and fatal). Input Rule 7 is to be widened to list all three (ADR-0001 Migration Plan item 2, a GDD edit). | Low | ADR-0001 |
| QQ-21 | Android gesture insets: the pinned reference has no Godot API for them, so presses near a back-swipe edge are rejected only by `edge_reject_margin` (data, 0 to 48) at MVP. Find the engine source, or confirm the margin is enough, before the first phone release. Raised by ADR-0003 (sync item A3); it is the open part of TR-input-006. | Medium | Mobile Platform GDD |
