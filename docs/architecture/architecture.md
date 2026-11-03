# TowerRiot: Master Architecture

## Document Status
- Version: 2
- Last Updated: 2026-11-03
- Version 2 applies GF1 to GF11. GF5 (phone spike) is closed by user decision 2026-11-03: the ADRs are accepted on best-guess device assumptions.
- Engine: Godot 4.7.2 (pinned 4.7; `Installed at pin time` 4.7.2.stable.official.ed1daf0bf), GDScript, Mobile renderer, Godot Physics 2D (not used by gameplay)
- Run mode: `review_mode full`, `automation autonomous`, `workflow full`, `docs.density thorough`
- GDDs Covered (all 10 design files in `design/gdd/`; the 10 cross-review reports were not re-reviewed):
  `game-concept.md`, `systems-index.md`, and the 8 MVP system GDDs (all at workflow tier `standard`):
  `data-config-pipeline.md`, `input-gesture-resolver.md`, `game-state-stage-flow.md`, `combat-damage.md`,
  `enemy-wave.md`, `tower-system.md`, `hero-system.md`, `battle-hud.md`
- Cross-review state: `design/gdd/gdd-cross-review-2026-11-02j.md`. Blockers L1 to L3 are fixed. Warnings M1 to M11 are carried into
  Open Questions and the Required ADRs below. This run did not re-review the GDDs.
- ADRs Referenced: ADR-0001 to ADR-0005 are Accepted (ADR-0001 to ADR-0003 on 2026-11-02, ADR-0004 and ADR-0005 on 2026-11-03; their Migration Plan edits are applied). `docs/architecture/` also holds `tr-registry.yaml` (`requirements: []`). Eight ADRs are required, numbered in writing order, plus a deferred Mobile Platform ADR (see Required ADRs). ADR-0006 to ADR-0008 are Accepted (2026-11-03, on the best guesses in `docs/architecture/device-assumptions.md`; their Migration Plan edits are applied). All eight required ADRs are Accepted.
- Technical Requirements Baseline: 65 requirements, 0 registered, 65 provisional. They are digests of the Detailed Design, Interactions and
  Dependencies sections, not copies of every acceptance criterion. Stories carry the finer detail.
- TD-ARCHITECTURE: REVISED after CONCERNS (2026-11-02): the design is sound; the concerns are listed under Gate Findings, and Version 2 settles all but GF5.
- LP-FEASIBILITY: REVISED after CONCERNS (2026-11-02): buildable by a small team in GDScript as laid out; the concerns are listed under Gate Findings, and Version 2 settles all but GF5.

---

## Gate Findings (2026-11-02)

Both director gates returned CONCERNS. Neither blocks ADR writing. Version 2 applies every item. **Done** means this document now carries the fix, in the named section. **Decided** means the decision is made here and the named ADR confirms it. **Open** means work is still to do. ADR numbers below are the new ones (see the renumbering note in Required ADRs).

| ID | Source | Finding | Settled by |
|----|--------|---------|------------|
| GF1 | TD | API Boundaries 4.2 leaves out the resolver's `set_centre(id, pos)` and `set_enabled`, which the Input GDD defines; without `set_centre` the hero's hit disc cannot follow a walking hero (TR-hero-008). | **Done**: API Boundaries 4.2 |
| GF2 | TD, LP | API Boundaries 4.3: `Battle` exposes no route to its systems, which the HUD and the ADR-0004 harness need. | **Done**: API Boundaries 4.3 (typed `flow()`, `combat()`, `wave()`, `tower()`, `hero()` and `systems()`) |
| GF3 | TD | The ADR Audit traceability table and the Technical Requirements Baseline disagree on several TR-to-ADR links (input-006, enemy-007, enemy-008, tower-001, hero-001). | **Done**: Technical Requirements Baseline (the source) and ADR Audit, Traceability coverage (derived from it row by row) |
| GF4 | TD, LP | The HUD ADR's stretch and coordinate-space choice fixes the space the input ADR and `targets()` use, and High items A4 and M6 hang on it. | **Done**: Required ADRs (ADR-0006 is must-have, before ADR-0007; TR-hud-005 and TR-hud-008 go to the deferred Mobile Platform ADR) |
| GF5 | TD, LP | Touch events, the `canceled` flag, lifecycle notifications, safe-area APIs and catalogue export are NOT SOURCEABLE (A7). | **Closed by user decision 2026-11-03: accepted on best-guess assumptions (docs/architecture/device-assumptions.md); the first device build runs its checklist.** |
| GF6 | TD | Lifecycle has two owners (InputAdapter and BattleWrapper); the adapter is rebuilt on Retry. No GDD handles the Android back button. | **Confirmed, ADR-0008**: Module Ownership, Data Flow 3.2 and 3.5, API Boundaries 4.2 (one owner, the BattleWrapper; back is Pause in a battle) |
| GF7 | TD, LP | Determinism should not depend on unverified engine event order, and the fixed tick has no clamp, catch-up cap or per-tick budget. | **Done** (ADR-0003 Accepted): Data Flow 3.1, API Boundaries 4.3 (command queue, at most 5 ticks per frame, 2 ms per tick proposed) |
| GF8 | TD, LP | Data Flow 3.6's "check `halted()` after each accessor read and each signal" cannot be enforced or tested. | **Confirmed, ADR-0008**: Data Flow 3.6, API Boundaries 4.1 and 4.5 |
| GF9 | LP | The catalogue record type is open ("Dictionary or typed record"); a Dictionary also breaks the read-only rule (TR-data-005). | **Decided**, ADR-0001 confirms: API Boundaries 4.1 (typed read-only records) |
| GF10 | LP | Canonical signal and read signatures differ between GDDs (M4). | **Done** (ADR-0002 Accepted): Required ADRs (one table of canonical signatures, written before any story); the edits in ADR-0002's Migration Plan are applied in 3.2 and 4.2 to 4.6 |
| GF11 | TD | ADR numbers do not follow writing order (0008 sits mid-list). | **Done**: Required ADRs (renumbered in writing order, with an old-to-new note) |

TD recommendations, now decided here (the named ADRs confirm): A1 is accepted: ProjectileSpawner is cut and the tick order stays (ADR-0005). A2 is accepted: the composition root is a plain builder, and TowerSim/TowerInput and HeroSim/HeroInput are split (ADR-0008). A3 is accepted: path and slots live on the Stage record (ADR-0001). Smaller items, also decided: `wave_called_early` carries `ticks_left: int`, and the HUD derives seconds for display (ADR-0002); the `Object` enemy parameters are typed (ADR-0005); the Catalogue returns are typed (ADR-0001).

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
  loop). Each is a required ADR before code (ADR-0001 for Data, ADR-0007 for the adapter, ADR-0003 and ADR-0008 for Flow).
- No Core or Foundation module touches physics, navigation or networking.

---

## Module Ownership

Format: Owns (sole writer), Exposes, Consumes, Engine APIs. Risk tags are from the Engine Knowledge Gap Summary.

### Foundation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| Catalogue | Every authored record (Tower, Enemy, Wave, Stage, Hero, Burst, Input, Options) as typed read-only records | Typed lookups by stable ID, `is_tower(id)`, level counts, Stage and Wave records, Input and Options records | JSON data files from an explicit manifest (ADR-0001) | `FileAccess` and an instance `JSON` parser (HIGH, NOT SOURCEABLE for export: ADR-0001 V1) |
| Validator | The error list `{code, source, record_id, field}` and the all-or-nothing load result | `validate(data: Dictionary, source_label: String) -> Array[CatalogueError]` (ADR-0001) | Plain parsed data, the schema table | None |
| StatAccessor | The vocabulary of stat keys and their types | `get_int(ctx, key)`, `get_float(ctx, key)` | Catalogue, read context (`def_id`, level, optional live entity) | None |
| GestureResolver | Target registry, one active pointer, the four-state machine, gesture log | Signals `pressed`, `tap`, `drag_started`, `drag_moved`, `drag_ended`, `drag_cancelled`, `ground_tap`, `idle`; calls `register`, `unregister`, `set_centre`, `set_enabled`, `cancel`, `cancel_pointer` | Input record | None (pure) |
| FieldSpace | The 540 x 960 field rect and the canvas-to-field transform (ADR-0006) | `FIELD_SIZE`, `FIELD_RECT`, `make`, `to_field`, `to_canvas`, `contains`, `margin_rects`, `mirror_x` | Visible rect | Viewport visible rect (HIGH, D3) |
| FieldInsets | Safe-area insets in field units (ADR-0006) | `FieldInsets.from(space, safe)` | FieldSpace, SafeAreaSource | None |
| SafeAreaSource | The one wrapper of the platform safe-area call (ADR-0006) | `safe_rect_canvas() -> Rect2` | Options record (fallback insets) | `DisplayServer` safe area (NOT SOURCEABLE, D4) |
| InputAdapter | Translation of engine events into the five resolver calls through `PointerGate` (ADR-0007), including reporting a touch cancel; drops presses outside `FIELD_RECT`; no lifecycle state | Nothing outward; owns the press-to-release guarantee | `GestureResolver`, engine input events | `Node._input`, touch and mouse events (HIGH, NOT SOURCEABLE), `Control.mouse_filter` (HIGH) |

### Core

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| AppRoot | Catalogue lifetime, launch ID, `attempt_seq`, `call_prompt_done`, the fatal screen, the Retry latch; calls `BattleBuilder.build` (ADR-0008) | `fatal(cause)`, `request_retry()`, `set_call_prompt_done()`, `on_lifecycle(state)` | Catalogue load result, lifecycle states forwarded by BattleWrapper | `Node` main scene, `remove_child` then `free()` (ADR-0008 section 9; L6 fallback `queue_free`) |
| BattleBuilder | Construction and signal connection of one battle | `build(catalogue, stage_id, seed, fatal_handler) -> Battle` | Every battle system | None (pure function) |
| StageFlow | Phases, lives, outcome latch, `halted()`, `intermission_left`, `to_ticks` | `tick(dt)`, `start_next_wave()`, `phase`, `lives_changed`, `wave_called_early(ticks_left: int)`, `in_build()`, result | Wave signals, Stage record | None |
| BattleWrapper | Tick accumulator and clamp, adapter, views, HeroInput, TowerInput; sole owner of app lifecycle (focus lost, focus gained, quit requested, resized, Android back) | `lifecycle_changed(state)`; forwards each state to AppRoot | Battle, engine frame, engine notifications | `Node._process`, `_notification` (HIGH, NOT SOURCEABLE) |
| Combat | The `EnemyHealth` and `EnemyStatus` components on each `EnemyInstance` (created by `attach`), all HP changes, per-source counters (ADR-0005) | `attach`, `deliver(event)`, `report_attack`, `tick_status`, `apply_slow`, `speed_factor`, `is_dead`, `hp_left`, `first_in`, `nearest_in`, `all_in_radius`, `counters()`, `snapshot()`, `attack_fired`, `damage_applied` | Positions and values passed in | None |

### Feature

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| WaveSim | Roster, `spawn_id`, `distance`, `position`, `in_play`, wave index, schedule, leaks, reap, `got_through_by_type` (ADR-0005) | `start_next_wave()`, `advance()`, `reap()`, `add_enemy(def_id)`, `roster()` and `targets()` (each a new typed copy per call), `wave_index()`, `snapshot()`, `enemy_killed(bounty)`, `enemy_leaked(lives_cost)`, `wave_cleared(intermission_duration)`, `waves_complete` | Stage and Wave records, StatAccessor, Combat state | None |
| TowerSim | Gold, slot states, tower instances, attack timers | `build(slot_index, tower_id)`, `upgrade(slot_index)`, `gold()`, `slot_state(slot_index)`, `gold_changed`, `tower_built(slot_index, tower_id)`, `tower_upgraded(slot_index, level)` | `enemy_killed`, `targets()`, `slot_positions`, Combat API, StatAccessor | None |
| TowerInput | Slot and tower registration, the upgrade chip window | `slot_tapped(slot_index)`, `tower_inspected(slot_index)`, `upgrade_refused(slot_index)`, `chip_state()` | GestureResolver, TowerSim commands | Real-time clock for the chip (`Time` singleton, LOW) |
| HeroSim | Position, pin, leash, burst state, cooldown, counters | `pin(position)`, `burst(aim_point)`, `position()`, `pin_state()`, `pin_target()`, `burst_state()`, `cooldown_left()`, `counters()`, `hero_pinned`, `burst_started` | `targets()`, Combat API, StatAccessor, Stage record, Options | None |
| HeroInput | Hero, burst button and sink registration; the hero disc centre, set with `set_centre` every frame while the hero walks; aim and cancel hysteresis; aim-point offset | none outward | GestureResolver, HeroSim commands | None |

### Presentation

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| Battle HUD | Presentation state only: arc, Start/Call arming, prompts, rejection ring, result text, paused overlay, human debug log | none | Reads of Tower, Hero, Wave, Flow, Combat; signals listed in Data Flow | `Control`, `CanvasLayer`, `_draw`, `Tween` (UI HIGH, Animation MEDIUM), safe area (NOT SOURCEABLE) |
| Combat view | Tracer lines and flashes | none | `attack_fired`, `damage_applied` | `CanvasItem.draw_line` (Rendering HIGH: thinner lines in 4.7) |
| Stage scene | Field hue, base value, grid tilt (look only) | none | Stage `scene_ref` | `PackedScene.instantiate()` (LOW) |
| Curtains | The margin rects outside the field, drawn over (ADR-0006) | none | FieldSpace `margin_rects` | `CanvasLayer`, `_draw` (LOW) |
| EnemyLayer | Pooled enemy presentation records drawn by one canvas item (ADR-0006) | none | `roster()`, `position()` | `CanvasItem._draw` (LOW) |

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
2. **Wave is the only writer of the roster.** Readers get copies, read-only by rule and valid for their own tick slot only (ADR-0005).
3. **Tower owns gold. Flow owns lives.** Nobody else writes either.
4. **Data owns no behaviour and emits no signals.** Each emitter declares its own signals (Data GDD, Not owned).
5. **Views hold no gameplay state.** Retry rebuilds them.
6. **Dealer and grantor are separate fields.** `source_kind` and `source_id` name the dealer. A future modifier's grantor gets its own field.
7. **Lifecycle has one owner, the BattleWrapper.** It forwards each state to AppRoot. The InputAdapter owns no lifecycle state and only reports touch cancels to the resolver (GF6, ADR-0008 confirms).
8. **Commands go through one queue.** Input and bots queue commands; the wrapper drains them once per frame before the ticks, and `battle.tick` drains first for headless callers (GF7, ADR-0003).

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
  |                                              commands (pin, burst, build, upgrade, Start/Call) are QUEUED here,
  |                                              on the input call stack; nothing in the sim runs yet
  v
AppRoot._process(delta)  ->  wrapper.step(delta):                 budget: 2 ms per tick on the target phone (proposed)
  a. chip feed        TowerInput.advance_chip(now_ms); hud.advance(min(delta_ms, 100))
  b. lifecycle, then battle.apply_queued()                        every frame, even with the clock stopped
  c. ticks            0 to 5 x battle.tick(DT), DT = 1/60         clock stopped: no tick, accumulator = 0
        halted()? stop                                            also checked at every slot edge below
        (tick starts with apply_queued(), a no-op after step b; it serves headless callers)
        each row below is a TickSlot the builder builds (ADR-0004)
        1. StageFlow (phase clock, intermission countdown)
        2. WaveSim.advance() (spawn, move, leak)                  leaks resolve before fire
        3. Status countdown  combat.tick_status(wave.roster())
        4. TowerSim by slot index
        5. HeroSim, then burst
        6. WaveSim.reap()    (kills, bounty, clear checks)
  d. outcome step     if an outcome or Fatal latched: stop clock, emit phase(...), request cancel()
  e. hero disc        HeroInput.set_centre(hero_id, hero position)
  f. views redraw from reads (roster(), position(), cooldown_left(), counters)
  f2. late outcome step for a Fatal latched during f
  g. cancel the resolver if requested, then gate.forget_open_presses();
     then, after a forwarded resized, rebuild FieldSpace and insets
AppRoot end of frame: Fatal latch first, then the quit check, then the Retry latch (ADR-0008)
```

Decided here (GF7), ADR-0003 (Accepted) sets the order and the phone spike measures:

- **Command queue.** Input handlers queue commands from the input call stack. The wrapper drains the queue once per frame, in arrival order, before the frame's ticks, even when the clock is stopped. `battle.tick` also drains first, so headless callers (bots, tests) need no wrapper. Bots use the same queue. Determinism no longer depends on the engine's event order within a frame, which is still **unverified** (Battle HUD Rule 18, Combat open question).
- **The GDD rule still holds.** "Commands run before the frame's ticks" is true: the drain comes before any system ticks. A frame that owes no tick still drains.
- **Clamp.** At most 5 catch-up ticks per frame. The rest of the accumulator is dropped, and development builds log the drop.
- **Budget.** 2 ms per tick on the target phone (proposed). The phone spike measures it.

### 3.2 Event and signal path

| Data | Producer | Consumer | Kind |
|---|---|---|---|
| `enemy_killed(bounty: int)` | WaveSim (reap) | TowerSim (gold) | Signal, synchronous, wired in builder |
| `enemy_leaked(lives_cost: int)` | WaveSim (leak) | StageFlow (lives) | Signal, synchronous, before `waves_complete` |
| `wave_cleared(intermission_duration: float)`, `waves_complete` | WaveSim | StageFlow | Signal |
| `wave_called_early(ticks_left: int)` | StageFlow | TowerSim (bonus gold) | Signal; seconds are derived only for display |
| `phase(state)`, `lives_changed(current)` | StageFlow | Battle HUD, TowerInput (chip) | Signal (view allowlist) |
| `gold_changed(current: int)`, `tower_built(slot_index: int, tower_id: StringName)`, `tower_upgraded(slot_index: int, level: int)` | TowerSim | Battle HUD | Signal (view allowlist) |
| `hero_pinned(position)`, `burst_started(aim_point, telegraph_ticks)` | HeroSim | Battle HUD | Signal (view allowlist) |
| `attack_fired(source_kind, source_id, origin, impact, radius)` | Combat | CombatView only (not the Battle HUD) | Signal, copied positions (view allowlist) |
| `damage_applied(event, applied, position)` | Combat | CombatView, Battle HUD | Signal, copied positions (view allowlist) |
| `slot_tapped`, `tower_inspected`, `upgrade_refused` | TowerInput | Battle HUD | Signal, wrapper only |
| `lifecycle_changed(state)`: focus lost, focus gained, quit requested, resized, back | BattleWrapper (sole lifecycle owner, GF6) | StageFlow (pause; Android back in a battle is Pause), HUD; forwarded to AppRoot by `AppServices.on_lifecycle` (a callable, not a signal connection); `resized` does not pause | Signal |
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
3. AppRoot starts InStage: AppRoot calls BattleBuilder.build(catalogue, stage_id, seed, fatal_handler);
   the wrapper's prepare() loads the stage scene, then attach() (ADR-0008)
       a. HaltLatch, StatAccessor and TickConverter first, then Combat, WaveSim, TowerSim, HeroSim, StageFlow
       b. all signal connections, then one TickSlot per row of 3.1; build returns a Battle, never null
          (halted() is true after a Fatal, and the root discards it)
       c. wrapper prepare() loads the stage scene by `scene_ref` (a broken scene is a Fatal, M2);
          attach() builds InputAssembly (GestureResolver, HeroInput, TowerInput), the gate, InputAdapter, views, Battle HUD
4. The wrapper calls StageFlow's announce method, which emits phase(Build) once, after views connect;
   headless, the caller of build calls it (never after a pre-view Fatal)
5. Clock stays stopped until the player taps Start Wave
```

### 3.5 Retry path

`Retry` tap sets a latch on AppRoot. The root's frame acts on it: stop the clock, cancel input inline, free the old battle and its views at
once, build a new battle, new resolver, new adapter, new views. It runs between ticks and never inside a signal. Only the root, its counters
(`launch ID`, `attempt_seq`, `call_prompt_done`) and the Catalogue survive. ADR-0008 section 9 sets the sequence: `wrapper.shutdown()` (cancel input, `forget_open_presses()`, block input, disconnect, `battle.dispose()`, drop references), then `remove_child`, then an immediate `free()`, then a new attempt. If L6 shows that `free()` errors or leaves orphans, the fallback is `queue_free()` after `remove_child`. The BattleWrapper
is rebuilt too. That is safe for lifecycle: the new wrapper subscribes to the engine notifications again, so lifecycle keeps one owner.

### 3.6 Fatal path

The failure handler is idempotent and keeps the first cause. It latches the battle and the root. `halted()` turns true at once, the tick loop
skips the remaining slots, the clock stops after the tick returns, and nothing persists. GDScript has no exceptions, so the calling function still
finishes. Decided here (GF8), confirmed by ADR-0008 section 10:

- **Where `halted()` is checked.** The tick loop checks it at every tick-slot edge, and each signal emitter checks it before it emits. Systems do
  not check it after each read, except WaveSim's `add_enemy`, leak and reap loops, which check it right after each accessor read and stop
  (ADR-0005). Both checks can be tested.
- **Reads after Fatal.** The stat accessor returns a typed zero value of the declared type (`0` for `get_int`, `0.0` for `get_float`), so the
  rest of the calling function runs safely to its end.
- **Runtime Fatal sources.** Only three: the stat accessor (a bad read), the builder (inside `build`), and the BattleWrapper's stage scene load (in `prepare()`, ADR-0008).
  Catalogue load failure is a boot Fatal, before any battle.

---

## API Boundaries

Pseudocode is GDScript. Names follow `project.yaml` (`PascalCase` classes, `snake_case` members, past-tense signals). Engine types used in an
interface are flagged. Where two GDDs spelled one name differently (warning M4), the form below is the canonical one fixed by ADR-0002.

### 4.1 Data and stat accessor (Foundation)

```gdscript
class_name Catalogue extends RefCounted
# Read-only after load. No setters. No fallbacks.
static func from_data(data: Dictionary, source_label: String, on_failure: Callable) -> Catalogue  # ADR-0001
# Records are typed read-only records, not Dictionaries (GF9; ADR-0001 confirms the type names).
func tower(def_id: StringName) -> TowerDef
func stage(stage_id: StringName) -> StageDef        # carries path_points, slot_positions, path_width (A3)
func wave(wave_id: StringName) -> WaveDef
func is_tower(def_id: StringName) -> bool
func level_count(def_id: StringName) -> int

class_name StatAccessor extends RefCounted
# Invariant: a level passed for an Enemy, Hero or Burst is a bad call.
# Invariant: unknown key fails here. Returns the type the key table declares.
# After Fatal: returns a typed zero value (0 or 0.0) of the declared type (GF8).
func get_float(ctx: ReadContext, key: StringName) -> float
func get_int(ctx: ReadContext, key: StringName) -> int

class_name ReadContext extends RefCounted
var def_id: StringName
var level: int          # Towers only
var entity: RefCounted = null  # live tower, hero or enemy; unused at MVP; null for a HUD cost preview (ADR-0001)
```

Guarantees: every error carries `{code, source, record_id, field}`; the game does not start with an invalid catalogue; tests build fixture
catalogues in code with no file I/O. Decided here (GF9), ADR-0001 confirms: catalogue records are typed read-only records, not Dictionaries,
because a Dictionary can be written and so breaks TR-data-005. ADR-0001 (Accepted) stores the data as JSON listed in a manifest and checks it
against a code schema, so missing-field detection does not rest on engine defaults; `Catalogue.from_data` builds fixtures with no file I/O.

### 4.2 Input resolver and adapter (Foundation)

```gdscript
class_name GestureResolver extends RefCounted
# Signal shapes follow the Input GDD. best_tap and best_drag are target IDs, or -1 for none.
signal pressed(best_tap: int, best_drag: int, pos: Vector2)
signal tap(target_id: int, pos: Vector2)
signal drag_started(target_id: int, press_pos: Vector2, pos: Vector2)
signal drag_moved(target_id: int, press_pos: Vector2, pos: Vector2)
signal drag_ended(target_id: int, press_pos: Vector2, pos: Vector2)
signal drag_cancelled(target_id: int)
signal ground_tap(pos: Vector2)
signal idle()

func register(owner_tag: StringName, shape: Dictionary, priority: int, gestures: int) -> int
func unregister(target_id: int) -> void
func set_centre(target_id: int, pos: Vector2) -> void      # owner moves its disc (the hero walks)
func set_enabled(target_id: int, enabled: bool) -> void    # false: out of hit tests, still registered (a built slot)
func press(index: int, pos: Vector2) -> void
func move(index: int, pos: Vector2) -> void
func release(index: int, pos: Vector2) -> void
func cancel_pointer(index: int) -> void
func cancel() -> void        # host-driven only; resolver has no cancel gesture

class_name InputAdapter extends Node
# No signals. Owns no lifecycle state (GF6): it only turns engine events into the five
# resolver calls, and reports a touch cancel as cancel_pointer. Lifecycle lives in BattleWrapper.
func setup(gate: PointerGate) -> void
func _input(event: InputEvent) -> void          # decided: _input on a Node (ADR-0007)

class_name PointerGate extends RefCounted       # pure gate (ADR-0007)
const MOUSE_INDEX: int = 1024                   # desktop mouse as one pointer
func set_space(space: FieldSpace, insets: FieldInsets) -> void
func set_input_blocked(blocked: bool) -> void   # ADR-0006 name; forwards nothing, never cancels
func forget_open_presses() -> void              # wrapper only, right after resolver.cancel()
# modal_sink: Callable                          # optional ADR-0006 fallback if D6 fails

class_name FieldSpace extends RefCounted        # Foundation (ADR-0006): FIELD_SIZE, FIELD_RECT, to_field, contains
```

Registry calls (`register`, `unregister`, `set_centre`, `set_enabled`) follow the Input GDD (Detailed Rules, fields `centre` and `enabled`):

- They are legal in every state, including inside a handler, and are never deferred.
- They cannot change a gesture in progress. Winners and discs freeze at press: a target moved, disabled or unregistered mid-gesture still gets
  the rest of that gesture's signals, and the release tests its frozen disc.
- `set_centre` with a non-finite position calls `push_error` and keeps the old centre. A call that names an unknown id is a no-op with a debug error.
- `set_enabled(id, false)` removes a target from hit tests without unregistering it.
- The hero's centre changes every frame while the hero walks. HeroInput calls `set_centre` each frame from the view's position, so the hit
  disc follows the walking hero (TR-hero-008).

Invariants for callers: owners register themselves, the resolver never names a feature, and one press yields exactly one tap, one drag or nothing,
delivered to one target. **Adapter contract (binding):** every `press` the adapter forwards is followed by exactly one `release`, one
`cancel_pointer` or one `cancel()` of that index, whatever Controls lie under the drag and whatever the OS does. The adapter checks a touch's
`canceled` flag before treating it as a release. Engine-type flags: touch event classes, `canceled`, and event delivery past a
`mouse_filter = STOP` Control are **NOT SOURCEABLE** (HIGH). Mouse events must be told apart by event class, not `device == 0` (4.7). The adapter drops a press outside `FieldSpace.FIELD_RECT` (ADR-0006). While the press block is on, the gate forwards nothing and never cancels (ADR-0007). **Family lock:** a modal screen, and the gate, accept a release only from the family (touch or mouse) of the press they saw.

### 4.3 Battle builder and flow (Core)

```gdscript
class_name BattleBuilder extends RefCounted
static func build(catalogue: Catalogue, stage_id: StringName, seed: int,
		fatal_handler: Callable) -> Battle    # no scene, no real time; bots and tests call this
# Returns a Battle built from a BattleParts record; it may be halted and is never null. The builder creates the HaltLatch (ADR-0008).

@abstract
class_name TickSlot extends RefCounted     # one row of 3.1 (ADR-0004 section 4)
@abstract func run() -> void
@abstract func owner() -> RefCounted       # the system this slot ticks

class_name BattleParts extends RefCounted  # latch, slots: Array[TickSlot], flow, combat, wave, tower, hero

class_name Battle extends RefCounted
func _init(parts: BattleParts) -> void      # the builder fills BattleParts; tests may pass RecordingSlot objects
func tick(dt: float) -> void                  # the only way simulation time enters; called with DT only; drains the queue first
func halted() -> bool
func in_build() -> bool
func enqueue(command: BattleCommand) -> void  # input and bots queue commands here (GF7, ADR-0003); never applies
func apply_queued() -> void                   # drains in arrival order; the wrapper calls it each frame, tick() calls it first
func command_log() -> Array[CommandRecord]    # every drained command, for replay (ADR-0004)
func tick_count() -> int                      # ticks that ran slots
const DT := 1.0 / 60.0
# StageFlow.clock_running() -> bool            # the wrapper reads it to decide whether ticks run
# BattleCommand: abstract base (on_result Callable, apply, to_record); six subclasses: Build, Upgrade, Pin, Burst, StartNextWave, Resume (ADR-0008).
# CommandRecord: plain data (tick, kind, args, result); no callbacks.
func dispose() -> void                        # Retry backstop: disconnects signals and clears the system list
# Battle declares no signals. Every battle signal lives on a system in systems(), so the wiring test sees it.
# No system holds Battle. halted() reaches systems through a shared HaltLatch (RefCounted) that the builder creates
# and hands to Battle and each system: systems hold the latch, Battle holds the systems, nothing points back.

class_name StageFlow extends RefCounted
func start_next_wave() -> void                # Start/Call; reached through the queue; forwards to WaveSim
signal phase(state: StringName)               # Build, Wave, Intermission, Paused, Won, Lost, Fatal
signal lives_changed(current: int)
signal wave_called_early(ticks_left: int)     # whole ticks; the HUD derives seconds for display
func state() -> StringName
func lives() -> int
func intermission_left() -> int               # ticks
func result() -> BattleResult
func to_ticks(seconds: float) -> int          # the one float-to-tick conversion; forwards to TickConverter (ADR-0005)
func snapshot() -> Dictionary                 # tests only; format: ADR-0004 section 5
const SNAPSHOT_EXEMPT: Array[StringName]      # members left out, with reasons (ADR-0005 section 10)

# Typed reads of the sim objects (GF2). Views and the harness use these; systems never do.
func flow() -> StageFlow
func combat() -> Combat
func wave() -> WaveSim
func tower() -> TowerSim
func hero() -> HeroSim
func systems() -> Array[RefCounted]           # each slot owner once, in tick order; each has snapshot() (ADR-0004; ADR-0005 section 10)
```

Guarantees: commands are queued from the input call stack and drained once per frame before the frame's ticks (and first inside `tick` for headless callers, ADR-0003); the same stage,
seed and command script give the same result; `to_ticks(seconds)` is the one float-to-tick conversion. A Fatal inside `build` discards the
partial battle (see warning M2 in Open Questions). Systems get each other only through the builder's wiring, never through these reads.

### 4.4 Combat (Core)

```gdscript
class_name SimEntity extends RefCounted            # base of every runtime instance (ADR-0005 section 1)
var def_id: StringName                             # set once in _init
var level: int = 0                                 # 0 means "no level" (ADR-0001)

class_name EnemyInstance extends SimEntity
var spawn_id: int                                  # set once; battle-wide; never reused
var distance: float                                # WaveSim writes
var position: Vector2                              # WaveSim writes; cached once per tick
var in_play: bool = true                           # WaveSim writes; false after a leak or reap
var health: EnemyHealth                            # Combat creates (attach) and writes
var status: EnemyStatus                            # Combat creates (attach) and writes

class_name EnemyHealth extends RefCounted          # hp(), max_hp(), is_dead(); Combat-only: seed(), remove()
class_name EnemyStatus extends RefCounted          # slow_strength(), slow_ticks_left(); Combat-only: set_slow(), count_down()
class_name TowerInstance extends SimEntity         # slot_index: int, cooldown_left: int ticks; TowerSim writes
class_name HeroInstance extends SimEntity          # position: Vector2; level stays 0; HeroSim writes

class_name DamageEvent extends RefCounted
var target: EnemyInstance
var amount: float
var source_kind: int        # TOWER, HERO, BURST
var source_id: StringName   # dealer's definition ID

class_name Combat extends RefCounted
func attach(enemy: EnemyInstance, max_hp: float) -> void   # WaveSim calls it once per enemy, in its add step
func deliver(event: DamageEvent) -> float          # returns applied; runs inside a tick only; returns 0.0 and emits nothing once halted
func apply_slow(enemy: EnemyInstance, strength: float, seconds: float) -> void
func speed_factor(enemy: EnemyInstance) -> float
func is_dead(enemy: EnemyInstance) -> bool
func hp_left(enemy: EnemyInstance) -> float
func report_attack(source_kind: int, source_id: StringName, origin: Vector2, impact: Vector2, radius: float) -> void
func tick_status(roster: Array[EnemyInstance]) -> void      # the Status slot
func first_in(list: Array[EnemyInstance], from: Vector2, range: float) -> EnemyInstance   # tie break: lowest spawn_id; skips the dead
func nearest_in(list: Array[EnemyInstance], from: Vector2, range: float) -> EnemyInstance
func all_in_radius(list: Array[EnemyInstance], center: Vector2, radius: float) -> Array[EnemyInstance]
func counters() -> CombatCounters
func enemy_snapshot(enemy: EnemyInstance) -> Dictionary   # the formatter WaveSim embeds
func snapshot() -> Dictionary                      # tests only; format: ADR-0004 section 5
const SNAPSHOT_EXEMPT: Array[StringName]           # ADR-0005 section 10
signal attack_fired(source_kind, source_id, origin, impact, radius)
signal damage_applied(event, applied, position)    # positions are copies; the target may be reaped
```

Guarantees: only the HP remaining counts toward the counters; a dead enemy takes and counts nothing; slow is one slot, whole ticks.

### 4.5 Wave, Tower, Hero (Feature)

```gdscript
# WaveSim
func advance() -> void                     # slot 2: spawn, move, leak, rebuild targets (ADR-0005 section 5)
func reap() -> void                        # slot 6: dead enemies in spawn_id order, then the clear check
func add_enemy(def_id: StringName) -> EnemyInstance   # the one add step; null if halted; no command reaches it
func roster() -> Array[EnemyInstance]      # a new typed copy per call, valid for the reader's own tick slot
func targets() -> Array[EnemyInstance]     # a new typed copy; roster limited to enemies whose centre is inside FieldSpace.FIELD_RECT (0..540, 0..960)
func wave_index() -> int
func got_through_by_type() -> Dictionary   # a copy
func snapshot() -> Dictionary              # tests only; format: ADR-0004 section 5
const SNAPSHOT_EXEMPT: Array[StringName]   # ADR-0005 section 10
signal enemy_killed(bounty: int)
signal enemy_leaked(lives_cost: int)
signal wave_cleared(intermission_duration: float)
signal waves_complete()

# TowerSim (commands reach it through Battle.enqueue, from the HUD and the bots alike)
func build(slot_index: int, tower_id: StringName) -> int    # OK, HALTED, BAD_SLOT, BAD_TOWER, SLOT_OCCUPIED, NO_GOLD
func upgrade(slot_index: int) -> int                        # OK, HALTED, BAD_SLOT, NO_TOWER, MAX_LEVEL, NO_GOLD
func gold() -> int
func slot_state(slot_index: int) -> SlotState               # tower_id (empty when unbuilt), level, cooldown_left (ticks)
func snapshot() -> Dictionary                               # tests only; format: ADR-0004 section 5
const SNAPSHOT_EXEMPT: Array[StringName]                    # ADR-0005 section 10

# TowerInput (wrapper-built, absent headless)
func chip_state() -> ChipState     # slot_index (-1 when closed), elapsed_ms (float, real time), level (int)

# HeroSim
func pin(position: Vector2) -> int      # OK, HALTED, BAD_POSITION, OUT_OF_BOUNDS, BUTTON_ZONE
func burst(aim_point: Vector2) -> int   # OK, HALTED, BUILD_PHASE, NOT_PINNED, NOT_READY, BAD_POSITION, OFF_FIELD, OUT_OF_REACH
func pin_target() -> Vector2
func burst_state() -> int
func counters() -> HeroCounters
func snapshot() -> Dictionary           # tests only; format: ADR-0004 section 5
const SNAPSHOT_EXEMPT: Array[StringName] # ADR-0005 section 10
```

`SlotState`, `ChipState` and `HeroCounters` are small read-only `RefCounted` records, not Dictionaries. ADR-0002 owns the full signature table. ADR-0005 section 4 gives the field lists: `SlotState` (`tower_id`, `&""` unbuilt; `level`, `0` unbuilt; `cooldown_left` ticks); `HeroCounters` (the Hero Rule 16 ints, plus `kills_per_burst()` and `kills_on_hit_3()` copies); `CombatCounters` (`source_ids()`, `amount`, `kind`, `kind_total`, `total`, `hero_share`, summed in `String(source_id)` order); `BattleResult` (`outcome`, `last_wave_started`, `lives_left`, `damage`).

Invariants: leak events fire synchronously and before `waves_complete`; `halted()` is checked by the tick loop at every slot edge and by each
signal emitter (Data Flow 3.6); no
system holds a target between attacks (re-pick every attack, so no reference dangles; ADR-0005 section 6); a burst is refused in Build.

### 4.6 Battle HUD (Presentation)

The HUD exposes nothing. It queues `start_next_wave` and TowerSim `build` and `upgrade` through `Battle.enqueue()`, calls `request_retry()` (the
Retry latch) and `set_call_prompt_done()` on AppRoot, reads through `Battle.tower()`, `hero()`, `wave()`, `flow()` and `combat()`, and listens to the
signals in Data Flow 3.2. Invariants: modal screens are full-screen Controls on layer 20 that take every event in `_gui_input` while the adapter's press block drops it (the block is the backstop, ADR-0006, ADR-0007); the Paused tap queues `ResumeCommand`; all commands
are queued from the input call stack and drained once per frame before the ticks, so they still run before the frame's ticks; refusals reach the HUD through each command's `on_result` in the same frame; Retry only sets a latch.

### 4.7 Engine type check (Phase 4 awareness)

| Type used in an interface | Where | Version note |
|---|---|---|
| `RefCounted`, `Node`, `Control`, `Callable`, `signal` | all | In training data, LOW |
| `StringName`, typed `Array`, `Dictionary` | all | LOW. 4.7 typed-return override rule applies to subclasses that override a typed method |
| `InputEventScreenTouch`, `InputEventScreenDrag`, `InputEventMouseButton`, `InputEventMouseMotion` | InputAdapter | **NOT SOURCEABLE** in the pinned reference (HIGH domain) |
| `InputEvent.DEVICE_ID_MOUSE` | InputAdapter | 4.7, confirmed in `breaking-changes.md` |
| `CanvasItem.draw_line` | CombatView, HUD | 4.7: no antialiasing feather |
| `Tween` | HUD | `tween_await()` new in 4.7; avoid in simulation |
| `DisplayServer` safe-area call | `SafeAreaSource` (ADR-0006) | **NOT SOURCEABLE** (D4) |
| Touch `canceled` flag | InputAdapter | **NOT SOURCEABLE** (I3) |
| `input_devices/pointing/emulate_mouse_from_touch`, `emulate_touch_from_mouse` | `project.godot` | Memory, unverified (I5) |
| `Node.PROCESS_MODE_ALWAYS` | InputAdapter, AppRoot | Memory, unverified |

---

## ADR Audit

### Existing ADRs

None. `docs/architecture/` holds no `adr-*.md` files. The ADR quality check (engine compatibility, version, post-cutoff flags, GDD linkage,
conflicts, validity) has nothing to check. This is recorded as a result, not a pass.

| ADR | Engine Compat | Version | GDD Linkage | Conflicts | Valid |
|---|---|---|---|---|---|
| (none exist) | n/a | n/a | n/a | n/a | n/a |

### Traceability coverage

Of 65 provisional requirements, **0 are covered** by an accepted ADR and **65 are gaps**. The Technical Requirements Baseline is the source of
truth for TR-to-ADR links. This table is derived from its ADR column row by row (GF3); change the Baseline first, then this table. Every gap maps
to a Required ADR below, to the deferred Mobile Platform ADR, or to stories. `/architecture-review` registers the IDs and builds the matrix.

| Required ADR | Requirements it will cover |
|---|---|
| ADR-0001 | TR-data-001 to 008, TR-enemy-008 |
| ADR-0002 | TR-flow-010, TR-combat-007, TR-hud-006 |
| ADR-0003 | TR-flow-003, 004, TR-tower-005, TR-hero-008, TR-hud-003 |
| ADR-0004 | TR-flow-011, TR-tower-007, TR-hero-005 |
| ADR-0005 | TR-combat-001 to 006, TR-enemy-001 to 006 |
| ADR-0006 | TR-input-006, TR-enemy-007, TR-hud-001, 002, 004, 007 |
| ADR-0007 | TR-input-001 to 005, 008 |
| ADR-0008 | TR-flow-001, 002, 005 to 009, TR-input-007, TR-tower-001, TR-hero-001 |
| Mobile Platform (deferred, not numbered) | TR-hud-005, 008 |
| Stories only (no ADR) | TR-tower-002 to 004, 006, TR-hero-002 to 004, 006, 007 |

---

## Technical Requirements Baseline

Extracted from 10 design GDDs (8 system GDDs plus the concept and the systems index; the 10 cross-review reports were used only for the open items)
| 65 total requirements | 0 registered, 65 provisional (TR registry: read, 0 entries, `requirements: []`). IDs come from
`bash .claude/scripts/registry.sh next-id tr <system>`, which gave `001` for every system. They are **provisional**: do not cite them as permanent
until `/architecture-review` registers them. No GDD contributed nothing; the concept contributed the performance targets (TR-hud-008).
**This table's ADR column is the source of truth for TR-to-ADR links** (GF3). ADR numbers are the Version 2 numbers. The traceability table in
ADR Audit and the Covers column in Required ADRs are derived from it.

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
| TR-input-001 (provisional) | input-gesture-resolver | Resolver is a pure object with no scene-tree dependency: registry, one active pointer, four-state machine, five input calls | Input | 0007 |
| TR-input-002 (provisional) | input-gesture-resolver | Each press yields exactly one tap, one drag or nothing, delivered to exactly one target by priority; owners register themselves | Input | 0007 |
| TR-input-003 (provisional) | input-gesture-resolver | Adapter guarantees every forwarded press ends in exactly one release, `cancel_pointer` or `cancel()` across Controls and OS touch-cancel | Input | 0007 |
| TR-input-004 (provisional) | input-gesture-resolver | Desktop mouse maps to one touch pointer; one physical press gives one gesture; events identified by class, not device 0 | Input | 0007 |
| TR-input-005 (provisional) | input-gesture-resolver | Hit radii and tap/drag slop meet the 44 pt / 48 dp minimum; at most 5% misses and zero mis-fires over 20 attempts on a phone | Input | 0007 |
| TR-input-006 (provisional) | input-gesture-resolver | Gesture coordinate space stays fixed for a gesture's life; resize or restretch cancels it; reference field 540 by 960; below 360 dp unsupported | UI | 0006 |
| TR-input-007 (provisional) | input-gesture-resolver | `lifecycle_changed(state)` covers focus lost, focus gained, quit requested, resized and Android back; its one owner is the BattleWrapper, not the adapter (GF6; the Input GDD names the adapter, a GDD fix) | Core | 0008 |
| TR-input-008 (provisional) | input-gesture-resolver | Gesture log records each gesture, including the landed pin position for a hero drag (fix L3) | Input | 0007 |
| TR-flow-001 (provisional) | game-state-stage-flow | Minimal app root, no autoload, holds catalogue, fatal screen, launch ID, `attempt_seq` and `call_prompt_done` across Retry | Core | 0008 |
| TR-flow-002 (provisional) | game-state-stage-flow | `build(catalogue, stage_id, seed, fatal_handler)` is a plain function with explicit signal connections and no scene, so bots run headless | Core | 0008 |
| TR-flow-003 (provisional) | game-state-stage-flow | Simulation time enters only through `battle.tick(dt)` at a fixed 60 ticks per second with a clamped accumulator (at most 5 ticks per frame, the rest dropped, GF7); no `_process`, timers, `await` or wall clock in gameplay | Core | 0003 |
| TR-flow-004 (provisional) | game-state-stage-flow | Fixed system tick order; commands queued and drained once per frame before the ticks, bots included (GF7, ADR-0003); same stage, seed and script give an identical result | Core | 0003 |
| TR-flow-005 (provisional) | game-state-stage-flow | Phase machine Build, Wave, Intermission, Paused, Won, Lost, Fatal with `phase` emitted on every change and once per built battle | Core | 0008 |
| TR-flow-006 (provisional) | game-state-stage-flow | Flow owns lives and the outcome; the outcome latches in two steps (`halted()` mid-tick, clock stop after); a tie is a loss | Core | 0008 |
| TR-flow-007 (provisional) | game-state-stage-flow | Retry rebuilds the whole battle, resolver, adapter and views; a latch on the root defers it to between ticks | Core | 0008 |
| TR-flow-008 (provisional) | game-state-stage-flow | Focus loss or backgrounding enters Paused; accumulator zeroed on resume; a tap resumes; quit and resize are handled (M1); Android back in a battle enters Paused (GF6) | Core | 0008 |
| TR-flow-009 (provisional) | game-state-stage-flow | Fatal handler is idempotent and keeps the first cause; the fatal screen loads without catalogue data | Core | 0008 |
| TR-flow-010 (provisional) | game-state-stage-flow | Wiring test: every signal of every battle system has a listener unless on the named view allowlist | Core | 0002 |
| TR-flow-011 (provisional) | game-state-stage-flow | Authored durations become whole ticks through one `to_ticks` conversion; tests can snapshot a battle, enumerate its systems and inject recording ones | Core | 0004 |
| TR-combat-001 (provisional) | combat-damage | All damage enters through `deliver(event)`, one event per victim, only inside a tick; nothing else changes HP | Core | 0005 |
| TR-combat-002 (provisional) | combat-damage | Only HP actually removed counts; per-source counters (`dealt[source_id]` with kind) stay readable after the outcome | Core | 0005 |
| TR-combat-003 (provisional) | combat-damage | All hits are instant (no projectiles); splash and burst victims are computed at release from current positions | Core | 0005 |
| TR-combat-004 (provisional) | combat-damage | One slow slot per enemy in whole ticks; stronger replaces, equal keeps longer, weaker ignored; `speed_factor` read by Wave | Core | 0005 |
| TR-combat-005 (provisional) | combat-damage | Pure targeting helpers `first_in`, `nearest_in`, `all_in_radius` over a caller list; ties by lowest `spawn_id`; skip the dead | Core | 0005 |
| TR-combat-006 (provisional) | combat-damage | Health and Status attach to an enemy instance; Combat reads no catalogue (`max_hp` passed at spawn) | Core | 0005 |
| TR-combat-007 (provisional) | combat-damage | `attack_fired` and `damage_applied` carry copied positions and drive a small view; nothing in gameplay depends on them | Rendering | 0002 |
| TR-enemy-001 (provisional) | enemy-wave | One continuous path per stage; stage geometry (`path_points`, `slot_positions`, `path_width`) is data on the Stage record | Core | 0005 |
| TR-enemy-002 (provisional) | enemy-wave | Waves are authored with no randomness; spawn ticks computed from wave start on an absolute schedule; battle-wide `spawn_id` | Core | 0005 |
| TR-enemy-003 (provisional) | enemy-wave | Speed read through the accessor each use, times `speed_factor`; one position per enemy per tick, cached | Core | 0005 |
| TR-enemy-004 (provisional) | enemy-wave | Leaks fire synchronously in `spawn_id` order, before `waves_complete`; a fatal leak stops the loop | Core | 0005 |
| TR-enemy-005 (provisional) | enemy-wave | Reap step in the tick: kills in `spawn_id` order emit `enemy_killed(bounty)`; clear check runs every tick while a wave is active | Core | 0005 |
| TR-enemy-006 (provisional) | enemy-wave | `roster()` and `targets()` are read-only lists valid in the reader's slot; an enemy is targetable only while its centre is inside the field | Core | 0005 |
| TR-enemy-007 (provisional) | enemy-wave | At most 48 enemies alive at once (`peak_alive_ub`); views pool enemy presentation records (one canvas item) | Rendering | 0006 |
| TR-enemy-008 (provisional) | enemy-wave | Content test enforces layout rules L1 to L13 and wave rules on real data; checks run in CI, not at boot | Core | 0001 |
| TR-tower-001 (provisional) | tower-system | TowerSim (pure, built by the builder) and TowerInput (wrapper-built, absent headless) are separate objects; the split is part of battle composition (A2) | Core | 0008 |
| TR-tower-002 (provisional) | tower-system | Gold changes only through `enemy_killed(bounty)`, build, upgrade and the early-call bonus; one `build` and `upgrade` command shared by the arc and the bots | Core | stories |
| TR-tower-003 (provisional) | tower-system | Three roles (single target, splash, slow) fire in slot-index order, first along the path; two levels, no selling | Core | stories |
| TR-tower-004 (provisional) | tower-system | Early-call bonus computed from `wave_called_early(ticks_left: int)` (seconds derived) and `early_call_seconds_per_gold`, never from burst state | Core | stories |
| TR-tower-005 (provisional) | tower-system | The upgrade chip needs real time while the clock is stopped; hard bounce guard of at least 200 ms before a commit tap; input order against the real-time feed | Input | 0003 |
| TR-tower-006 (provisional) | tower-system | TowerSim exposes `gold()`, `slot_state`, `gold_changed`, `tower_built`, `tower_upgraded`, and TowerInput exposes `chip_state` (ADR-0002), for the HUD | UI | stories |
| TR-tower-007 (provisional) | tower-system | Tower CI computes `peak_alive_ub` and layout rule L10 and runs in a headless battle | Core | 0004 |
| TR-hero-001 (provisional) | hero-system | HeroSim (pure) and HeroInput (wrapper-built) are separate, as part of battle composition (A2); the hero has no HP at MVP | Core | 0008 |
| TR-hero-002 (provisional) | hero-system | Pin sets a destination inside `pin_rect` and outside `pin_exclusion`; straight-line walk at `walk_speed`; leash is the whole reach | Core | stories |
| TR-hero-003 (provisional) | hero-system | Burst is drag-only from the button; aim point is finger plus (0, -100) clamped to reach; cancel hysteresis 64 out and 48 back; refused in Build | Input | stories |
| TR-hero-004 (provisional) | hero-system | Burst telegraph and release run in the Hero-and-burst tick slot with victims computed at release; cooldown runs from release | Core | stories |
| TR-hero-005 (provisional) | hero-system | Bots drive `pin` and `burst` through the builder; one equivalence test passes through the resolver; counters give kills per burst and hero share | Core | 0004 |
| TR-hero-006 (provisional) | hero-system | Hero exposes `position()`, `pin_state()`, `burst_state()`, `cooldown_left()`, `hero_target_id()`, `hero_pinned`, `burst_started` | UI | stories |
| TR-hero-007 (provisional) | hero-system | `left_hand` and `reduce_motion` read from the Options record; the burst button mirrors by hand | UI | stories |
| TR-hero-008 (provisional) | hero-system | HeroInput sits in the wrapper and calls `set_centre` every frame while the hero walks, so the hit disc follows the walking hero; queued commands make the input order against this update safe | Input | 0003 |
| TR-hud-001 (provisional) | battle-hud | Modal result and Paused screens are full-screen Controls that take every event in `_gui_input` while the adapter's press block drops it; the HUD holds no gameplay state | UI | 0006 |
| TR-hud-002 (provisional) | battle-hud | Build arc, Start/Call disc, upgrade chip and rejection ring register with the resolver at set priorities (arc discs TAP 300, backdrop TAP 250, Start/Call TAP 350) | Input | 0006 |
| TR-hud-003 (provisional) | battle-hud | All commands run from the input call stack before the frame's ticks (they are queued there and drained once per frame before the ticks, GF7, ADR-0003); Retry's handler only sets a latch (destroying its own caller is unsafe) | Core | 0003 |
| TR-hud-004 (provisional) | battle-hud | Layout anchors to safe areas and notches; tap targets at least 44 pt / 48 dp; portrait 540 by 960 reference | UI | 0006 |
| TR-hud-005 (provisional) | battle-hud | Human debug log writes per-attempt and per-wave records, a Fatal record and a provisional record on quit, with `call_prompt_shown` stamped (L1) | Core | Mobile Platform (deferred) |
| TR-hud-006 (provisional) | battle-hud | HUD reads values per frame, comparing whole ticks, and listens only to signals on the view allowlist | UI | 0002 |
| TR-hud-007 (provisional) | battle-hud | Start/Call arms over 300 ms of real time; `call_prompt_done` is set on the app root on the first call after the prompt shows (L2) | UI | 0006 |
| TR-hud-008 (provisional) | game-concept, battle-hud | 60 fps on a mid-range phone (30 floor on low-end Android), 16.6 ms frame, at most 60 draw calls, 256 MB memory, textures at most 16 MB | Rendering | Mobile Platform (deferred) |

---

## Required ADRs

ADR-0001 to ADR-0005 are Accepted; ADR-0006 to ADR-0008 are Accepted (2026-11-03) on the best guesses in `docs/architecture/device-assumptions.md`, by user decision; the first device build runs its checklist. These eight are required, numbered in the order they are written. Foundation first. Each ADR must record the engine version
(4.7.2), flag post-cutoff APIs, and list the TR-IDs it covers in "GDD Requirements Addressed". The Covers column is derived from the Technical
Requirements Baseline. Where a decision cell says **decided here**, this document has made the call and the ADR confirms it.

**Renumbering note (GF11, 2026-11-02), old to new:** 0001 stays 0001, 0004 to 0002, 0006 to 0003, 0008 to 0004, 0005 stays 0005, 0007 to 0006, 0002 to 0007, 0003 to 0008.

### Must have before coding starts (Foundation, Core, and the coordinate space)

| ADR | Layer | Decision to make | Covers | Engine risk |
|---|---|---|---|---|
| **ADR-0001 Catalogue Storage Format and Stat Accessor** | Foundation | Storage format (decided: JSON plus a code schema); how a missing field, fractional integer and unknown property are detected; read-only enforcement; accessor signature and key format; file locations; storage form of `path_points` and `slot_positions`; export check on Android and iOS. **Decided here:** records are typed read-only records, not Dictionaries (GF9); Catalogue returns are typed; path and slots live on the Stage record (A3) | TR-data-001 to 008, TR-enemy-008 | HIGH: JSON export packing NOT SOURCEABLE (V1) |
| **ADR-0002 Signal Contracts and Wiring Conventions** | Foundation | Typed signal declarations, explicit connections in the builder, no event-bus autoload, the view allowlist and how the wiring test derives its set, canonical interface names (M4). **Decided here:** this ADR owns one table of canonical signal and read signatures, written before any story (GF10); `wave_called_early` carries `ticks_left: int`. **Done: Accepted 2026-11-02** (the Migration Plan edits are applied to this document) | TR-flow-010, TR-combat-007, TR-hud-006 | MEDIUM: lambda capture by value, GDScript 4.7 typing |
| **ADR-0003 Frame Order: Command Queue, Ticks and View Update** | Core | Tick rate, accumulator and clamp; where TowerInput and HeroInput sit in the wrapper; input against the real-time chip feed and the per-frame hero centre update; the command type for `Battle.enqueue` and how a refused command reaches the HUD. **Decided here (GF7):** commands are queued from the input call stack and drained once per frame before the ticks (and first inside `tick` for headless callers), bots included; at most 5 catch-up ticks per frame, the rest dropped and logged in development builds; 2 ms per tick on the target phone (proposed; the phone spike measures it) | TR-flow-003, 004, TR-tower-005, TR-hero-008, TR-hud-003 | HIGH: frame order unverified (no longer load-bearing for determinism). **Done: Accepted 2026-11-02** (the Migration Plan edits are applied to this document) |
| **ADR-0004 Headless Battle Harness and Snapshot** | Core | How tests snapshot a battle (through `Battle.systems()`, in tick order), enumerate its systems and inject recording ones; bot commands through the builder and the command queue; gdUnit4 on 4.7.2. **Decided:** every battle system has `snapshot() -> Dictionary` (plain data, compared exactly with `SnapshotTool.diff`) and `SNAPSHOT_EXEMPT`; `Battle._init(parts: BattleParts)` runs an ordered list of `TickSlot` objects, so tests inject `RecordingSlot` objects with no builder branch; `Replay` rebuilds the command log and checks every result; gdUnit4 6.2.2 is pinned, and only exit 0 passes (100, 101 orphans, 103, 105 and 1 fail; `No test cases found` fails). **Done: Accepted 2026-11-03** (the Migration Plan edits are applied to this document) | TR-flow-011, TR-tower-007, TR-hero-005 | LOW: gdUnit4 6.2.2 runs on 4.7.2 per the reference |
| **ADR-0005 Simulation State Attachment: Health, Status and Roster** | Core | How Health and Status attach to an enemy instance; whether a future spawner sits behind `deliver`; roster and `spawn_id` representation. **Decided here:** ProjectileSpawner is cut and the tick order stays (A1); the `Object` enemy parameters are typed (`EnemyInstance`, name confirmed). **Done: Accepted 2026-11-03** (the Migration Plan edits are applied to this document) | TR-combat-001 to 006, TR-enemy-001 to 006 | LOW to MEDIUM (typed arrays, packed array write rule) |
| **ADR-0006 Stretch Mode, Coordinate Space, Safe Area and HUD Layering** | Presentation (coordinate space used by Foundation) | Stretch mode and aspect (set `display/window/stretch` on purpose); the coordinate space the resolver and `targets()` use; Control layering above the adapter; modal consumption; the Paused resume input route (M6); safe-area API (NOT SOURCEABLE); Control event order against the adapter; enemy and effect pooling; renderer check (Mobile versus Compatibility on low-end Android). Must-have, accepted before ADR-0007 (GF4). **Done: Accepted 2026-11-03** on best-guess device assumptions (the Migration Plan edits are applied to this document) | TR-input-006, TR-enemy-007, TR-hud-001, 002, 004, 007 | HIGH: safe area NOT SOURCEABLE; stretch defaults (A4) |
| **ADR-0007 Input Adapter and Gesture Path** | Foundation | Which Godot input path feeds the adapter (decided: `_input` on a Node, feeding a pure `PointerGate`; emulation off; the press block is the main modal route); how moves and releases of the active touch survive a `mouse_filter = STOP` Control; touch-cancel handling and how the adapter reports it; desktop mouse as touch; tablet slop. The adapter owns no lifecycle state (GF6). **Done: Accepted 2026-11-03** on best-guess device assumptions (the Migration Plan edits are applied to this document) | TR-input-001 to 005, 008 | HIGH: touch events NOT SOURCEABLE; verify against live 4.7 docs |
| **ADR-0008 App Lifecycle and Battle Composition** | Core | Main scene; app root; builder ownership and lifetime; retry teardown including views and `free()` timing; pause mechanism; which lifecycle notifications fire on iOS and Android; guarantee that the fatal scene loads; Fatal during or after `build` (M2); quit and resize handling (M1). **Decided here:** lifecycle has one owner, the BattleWrapper, forwarding to AppRoot, and Android back in a battle is Pause (GF6); the plain builder and the TowerSim/TowerInput and HeroSim/HeroInput splits (A2); `halted()` at tick-slot edges and in emitters, typed zero reads after Fatal, three runtime Fatal sources (GF8). **Done: Accepted 2026-11-03** on best-guess device assumptions (the Migration Plan edits are applied to this document) | TR-flow-001, 002, 005 to 009, TR-input-007, TR-tower-001, TR-hero-001 | HIGH: lifecycle NOT SOURCEABLE; needs a phone run |

ADR-0006, 0007 and 0008 were drafted before any phone test and accepted on best-guess device assumptions (GF5 and A7 closed by user decision 2026-11-03).

### Should have before the relevant system is built

None now. The HUD ADR moved to must-have as ADR-0006 (GF4).

### Can defer to implementation or a later tier

| Topic | Tier |
|---|---|
| Save/Load schema and versioning | Vertical Slice |
| Stat & Modifier resolver internals behind the accessor | Vertical Slice |
| Mobile Platform ADR (not numbered yet): export presets, device budgets, the debug log file writes and the performance budget (TR-hud-005, TR-hud-008) | Vertical Slice |
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
| M1 | Nothing handles `lifecycle_changed` "quit requested" and "resized"; the provisional HUD record has no writer | High | **Closed: decided by ADR-0008** (the BattleWrapper owns lifecycle; quit is checked at the AppRoot frame end; `resized` cancels without a pause). Flow Rule 17 routes both |
| M2 | A broken stage scene cannot Fatal "during `build`"; the wrapper loads `scene_ref` after `build` returns; who writes the Fatal record before views connect is unstated | High | **Closed: decided by ADR-0008** (the root builds; the wrapper's `prepare()` scene load is a runtime Fatal source, and the root writes the record) |
| M3 | `chip_state()` during `upgrade` (current or next level) is undefined | Medium | Tower stories; HUD story |
| M4 | Interface names and signatures differ between GDDs (`lifecycle_changed(state)`, `start_next_wave()`, `slot_tapped(slot_index)`, `chip_state()` fields, `bursts_started`, owner column) | Medium | **Closed: decided by ADR-0002** (one canonical signature table; the GDD fixes in its Migration Plan are applied) |
| M5 | HUD Rule 10 states the pin cancel more loosely than Hero Rule 14 | Low | HUD story: use "within 48 at release, or never passed 64" |
| M6 | The Paused resume tap has no input route | High | **Closed: decided by ADR-0006** (the Paused overlay is a Control on layer 20; its tap queues `ResumeCommand`) |
| M7 | Stale criteria and questions across GDDs (expired chip tap, wrong-disc question, snapshot question, hero share, ADR names) | Medium | Stories. The snapshot question is **Closed: decided by ADR-0004** |
| M8 | "First run (challenge)" cannot order attempts across launches (`attempt_seq` resets) | Low | HUD debug-log story: say file order is the timeline, or add a persistent `tester_seq` |
| M9 | `call_prompt_done` lasts one launch | Low | Design call; the app root holds it for one launch |
| M10 | The Call prompt may teach a free move | Low | Design call (Hero "Always-call, humans" gate) |
| M11 | A hero standing still in Build may read as a failed pin | Low | Playtest risk, not an architecture item |
| A1 | Does the technical director accept cutting ProjectileSpawner and the tick order? | High | **Closed: decided by ADR-0005.** Accepted: ProjectileSpawner is cut and the tick order stays (ADR-0005 section 8) |
| A2 | Does the technical director accept the composition root as a plain builder, and the HeroSim/HeroInput and TowerSim/TowerInput splits? | High | **Closed: decided by ADR-0008** (plain builder and both Sim/Input splits; TR-tower-001, TR-hero-001) |
| A3 | Does the technical director accept path and slots moving from the scene to the Stage record? | Medium | **Closed: decided.** Accepted: path and slots live on the Stage record. ADR-0001 confirms the storage form, ADR-0005 uses it (`PathTrack` from `stage.path_points()`, ADR-0005 section 5) |
| A4 | Stretch mode and aspect are unset in `project.godot`; 4.7 new-project defaults may not apply to this file | High | **Closed: decided by ADR-0006** (`canvas_items` and `expand`, base 540 x 960, portrait, written in `project.godot`) |
| A5 | Scene checks run on the project, not on an export (the test runner cannot run on an exported build); is the manual export check enough? | Medium | **Closed: decided** by ADR-0001. Yes for MVP: CI checks scene content, the manual export check covers packing |
| A6 | Tablet `drag_slop` is 22 dp wide at 800 dp; does it need a scale cap? | Low | **Closed: decided by ADR-0007** (no scale cap at MVP; reopen from tablet log data) |
| A7 | Phone spike: confirm touch event classes, the `canceled` flag, lifecycle notifications, safe-area APIs and Resource export on Godot 4.7.2 on a target phone, and extend `docs/engine-reference/godot/`; needed before drafting ADR-0006, 0007 and 0008. | High | **Closed by user decision 2026-11-03: accepted on best-guess assumptions (docs/architecture/device-assumptions.md); the first device build runs its checklist.** |
| A8 | Renderer: `project.godot` uses Mobile; the reference calls Forward+ desktop-focused and lists Compatibility as the widest. Confirm Mobile on the lowest target Android | Medium | **Closed: decided by ADR-0006** (keep Mobile), pending D9 on the lowest target Android |
| A9 | gdUnit4 is not installed; the framework runs on 4.7.2 per the reference | Medium | **Closed: decided by ADR-0004** (gdUnit4 6.2.2, pinned and committed under `addons/gdUnit4/`). The install is a `/test-setup` task |
| A10 | No GDD handles the Android back button. Decided here: in a battle it is Pause (GF6) | Medium | **Closed: decided by ADR-0008** (Android back in a battle is Pause); the Flow and HUD GDD fixes add the rule |
| A11 | With commands queued (GF7), a command's result (`build`, `pin`, `burst` enums) is known only at the next tick; how the HUD shows a refusal (the rejection ring) is unstated | Medium | **Closed: decided by ADR-0003** (the result reaches the HUD through each command's `on_result` in the same frame) |
