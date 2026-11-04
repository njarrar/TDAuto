# Architecture Traceability Index
Last Updated: 2026-11-04
Engine: Godot 4.7.2 (GDScript, Mobile renderer)
Built by: /architecture-review full, report `docs/architecture/architecture-review-2026-11-04c.md`
Requirement source: `docs/architecture/tr-registry.yaml` v4, 126 entries, all active

## Coverage Summary
- Total requirements: 126
- Covered by an Accepted ADR: 0 (0%)
- Covered by a Proposed ADR: 124 (98.4%), of which 4 are implicit (the ADR decides it in its Decision text but leaves it out of its GDD Requirements Addressed table)
- Partial: 2
- Gaps: 0

No requirement is covered by an Accepted ADR. All 11 ADRs are Proposed, and each lists engine runs (desktop, export or phone) that block its acceptance. Coverage resting on Proposed ADRs is not a pass state: stories that cite these ADRs stay blocked until `/architecture-decision accept ADR-NNNN`.

| GDD | TRs | Covered (Proposed) | Partial | Gap |
|-----|-----|--------------------|---------|-----|
| data-config-pipeline.md | 15 | 15 | 0 | 0 |
| input-gesture-resolver.md | 16 | 16 | 0 | 0 |
| game-state-stage-flow.md | 16 | 16 | 0 | 0 |
| combat-damage.md | 14 | 14 | 0 | 0 |
| enemy-wave.md | 17 | 15 | 2 | 0 |
| tower-system.md | 15 | 15 | 0 | 0 |
| hero-system.md | 15 | 15 | 0 | 0 |
| battle-hud.md | 18 | 18 | 0 | 0 |

| Layer | TRs |
|-------|-----|
| Foundation (data, input, state) | 47 |
| Core (combat, enemy) | 31 |
| Feature (tower, hero) | 30 |
| Presentation (hud) | 18 |

## Full Matrix

| Requirement ID | GDD | Layer | Requirement | ADR Coverage | Status |
|----------------|-----|-------|-------------|--------------|--------|
| TR-data-001 | data-config-pipeline.md | Foundation | Typed read-only records keyed by a stable snake_case ID unique across all record types; records reference each other by typed ID, never by file path | ADR-0002 | Covered (Proposed) |
| TR-data-002 | data-config-pipeline.md | Foundation | The storage format, or a check on top of it, detects a missing field, a fractional integer and an unknown property | ADR-0002 | Covered (Proposed) |
| TR-data-003 | data-config-pipeline.md | Foundation | The catalogue loads from an explicit manifest of data files, never a directory scan, and loads correctly from an Android export | ADR-0002 | Covered (Proposed) |
| TR-data-004 | data-config-pipeline.md | Foundation | Loading is once and all-or-nothing (Unloaded, Loading, Ready/Failed), started by the app root before the first gameplay scene, with no reload | ADR-0001 | Covered (Proposed) |
| TR-data-005 | data-config-pipeline.md | Foundation | The validator collects every error as {code, source, record_id, field} before failing, in tiers (manifest, finiteness, bounds, tags, references), and checks the Input record's cross-field tap_slop > drag_slop at load | ADR-0002 | Covered (Proposed) |
| TR-data-006 | data-config-pipeline.md | Foundation | No fallbacks in any build; a load failure shows a catalogue-free fatal screen that never opens saves, and dev runs name each error | ADR-0001 | Covered (Proposed) |
| TR-data-007 | data-config-pipeline.md | Foundation | Definitions are read-only after load and mutable state lives on runtime instances holding def_id; a deep-snapshot test proves the catalogue is unchanged after a battle | ADR-0002 | Covered (Proposed) |
| TR-data-008 | data-config-pipeline.md | Foundation | Every modifiable value is read through one stat accessor (read_context, stat_key) at use time, never cached, so Stat & Modifier Resolution can replace its internals with no call-site change | ADR-0005 | Covered (Proposed) |
| TR-data-009 | data-config-pipeline.md | Foundation | A bad accessor call goes to an injected, test-replaceable failure handler that survives release builds (not assert) | ADR-0001 | Covered (Proposed) |
| TR-data-010 | data-config-pipeline.md | Foundation | Data owns the stat-key vocabulary and int/float type per key, and exposes non-fatal level_count(def_id) and is_tower(id) | ADR-0005 | Covered (Proposed) |
| TR-data-011 | data-config-pipeline.md | Foundation | No autoload or global: the app root holds the Ready catalogue across retries and the battle builder injects it | ADR-0001 | Covered (Proposed) |
| TR-data-012 | data-config-pipeline.md | Foundation | Logic tests build fixture catalogues in code with no file I/O; a separate integration suite validates the real data files | ADR-0007 | Covered (Proposed) |
| TR-data-013 | data-config-pipeline.md | Foundation | A CI content test opens each Stage scene_ref, applies layout and wave rules, and checks rationale fields and owning-GDD balance ranges | ADR-0002 | Covered (Proposed) |
| TR-data-014 | data-config-pipeline.md | Foundation | The data store emits no signals; each emitter declares its own and the composition root wires them | ADR-0006 | Covered (Proposed) |
| TR-data-015 | data-config-pipeline.md | Foundation | Load-time targets: Loading to Ready median at most 1000 ms on an Adreno 5xx-class device; edit-to-in-game at most 10 s | ADR-0002 | Covered (Proposed) |
| TR-input-001 | input-gesture-resolver.md | Foundation | The resolver is a pure, scene-free, clock-free object driven only by press, move, release, cancel_pointer and cancel | ADR-0008 | Covered (Proposed) |
| TR-input-002 | input-gesture-resolver.md | Foundation | One thin adapter node is the only engine-facing input code; it maps Godot touch and mouse events to the five calls in 540x960 field units | ADR-0003 | Covered (Proposed) |
| TR-input-003 | input-gesture-resolver.md | Foundation | Every forwarded press is followed by a release or cancel for that index, and the first closes it, even under a mouse_filter STOP Control; the canceled flag is honoured | ADR-0003 | Covered (Proposed) |
| TR-input-004 | input-gesture-resolver.md | Foundation | The adapter runs PROCESS_MODE_ALWAYS and calls cancel() on app pause, focus loss and viewport resize, forwarding one lifecycle signal to Game State | ADR-0003 | Covered (Proposed) |
| TR-input-005 | input-gesture-resolver.md | Foundation | Touch and mouse use one event family: emulation settings stop duplicate presses, the mouse pointer index never collides with touch index 0, non-left buttons are dropped | ADR-0003 | Covered (Proposed) |
| TR-input-006 | input-gesture-resolver.md | Foundation | The adapter rejects presses inside edge_reject_margin and platform safe-area insets via DisplayServer.get_display_safe_area(), converted to field units | ADR-0003 | Covered (Proposed) |
| TR-input-007 | input-gesture-resolver.md | Foundation | A registry of disc hit targets {id, centre, radius, accepts, priority, enabled, sink}; register, unregister, set_centre and set_enabled are legal in any state and apply at once | ADR-0008 | Covered (Proposed) |
| TR-input-008 | input-gesture-resolver.md | Foundation | A four-state machine (Idle, Pressed, Dragging, Dead) with one active pointer freezes TAP and DRAG winners at press and classifies by per-press slop | ADR-0008 | Covered (Proposed) |
| TR-input-009 | input-gesture-resolver.md | Foundation | Signal API pressed, tap, ground_tap, drag_started, drag_moved, drag_ended, drag_cancelled, idle; every exit to Idle emits idle() last | ADR-0008 | Covered (Proposed) |
| TR-input-010 | input-gesture-resolver.md | Foundation | State commits before emit; gesture calls made inside a handler queue FIFO and drain synchronously in the outermost call | ADR-0008 | Covered (Proposed) |
| TR-input-011 | input-gesture-resolver.md | Foundation | Slops come by injection through static validate() and a create() factory returning null on bad input, and a null create() in the wrapper calls the failure handler; non-finite positions are dropped with push_error | ADR-0008 | Covered (Proposed) |
| TR-input-012 | input-gesture-resolver.md | Foundation | The battle wrapper builds the resolver and adapter per battle from the Input record and injects the one resolver into the Hero, Tower and HUD input objects; hit radii (36 to 56) are constants on those objects, not catalogue fields | ADR-0001 | Covered (Proposed) |
| TR-input-013 | input-gesture-resolver.md | Foundation | Burst button, build arc and world targets are resolver discs, not Controls; HUD Controls consume their events before the adapter, so routing order is fixed | ADR-0003 | Covered (Proposed) |
| TR-input-014 | input-gesture-resolver.md | Foundation | Identical call lists give identical signal logs; tests use a recording fake, not assert_signal; bots call commands directly plus one resolver equivalence test | ADR-0007 | Covered (Proposed) |
| TR-input-015 | input-gesture-resolver.md | Foundation | Dev builds carry a gesture-log harness recording device, insets, timing, travel, winners and classification, listening to tower_upgraded, chip_state() at tower prompts and burst_started (only it counts as a burst), for the Pillar 4 phone test | ADR-0008 | Covered (Proposed) |
| TR-input-016 | input-gesture-resolver.md | Foundation | Minimum width 360 dp by runtime guard; stretch mode keeps field units equal to viewport units, no Camera2D, and a cancel() on resize | ADR-0003 | Covered (Proposed) |
| TR-state-001 | game-state-stage-flow.md | Foundation | A minimal main-scene app root with no autoload triggers the catalogue load, holds the Ready catalogue, owns the fatal screen, and alone survives a retry | ADR-0001 | Covered (Proposed) |
| TR-state-002 | game-state-stage-flow.md | Foundation | A scene-free builder build(catalogue, stage_id, seed, fatal_handler) wires every battle system by explicit signal connections and runs headless, calling the handler and returning null when the stage cannot be built; a thin wrapper adds tick loop, resolver, adapter and views | ADR-0001 | Covered (Proposed) |
| TR-state-003 | game-state-stage-flow.md | Foundation | Simulation time enters only through battle.tick(dt) at a fixed rate; no _process, Timers, await, wall clock or physics areas in gameplay; the wrapper clamps owed ticks | ADR-0004 | Covered (Proposed) |
| TR-state-004 | game-state-stage-flow.md | Foundation | Systems tick in one fixed documented order and player and bot commands apply only between ticks | ADR-0004 | Covered (Proposed) |
| TR-state-005 | game-state-stage-flow.md | Foundation | All randomness comes from an injected seed so stage, seed and command script give an identical result | ADR-0004 | Covered (Proposed) |
| TR-state-006 | game-state-stage-flow.md | Foundation | Flow and lives are a pure stage state machine (Build, Wave, Intermission, Paused, Won, Lost, and Fatal as an absorbing state) with a result readable after the outcome; in_build() is true in Build and in Paused from Build; last wave started is Enemy & Wave's wave_index() | ADR-0004 | Covered (Proposed) |
| TR-state-007 | game-state-stage-flow.md | Foundation | Every transition commits state, then acts, then emits in a fixed order, and stops emitting if Fatal latched during an emit; phase fires on every state change; Won, Lost, Paused and Fatal stop the clock and cancel input before they emit; remaining systems skip the rest of that tick | ADR-0004 | Covered (Proposed) |
| TR-state-008 | game-state-stage-flow.md | Foundation | Flow listens to synchronous wave_cleared, waves_completed and enemy_leaked (leak before complete) and emits lives_changed, phase_changed and wave_called_early | ADR-0006 | Covered (Proposed) |
| TR-state-009 | game-state-stage-flow.md | Foundation | Retry destroys the whole battle and builds a new one between ticks, driven by a latch on the app root; a weakref to the old battle must be null | ADR-0001 | Covered (Proposed) |
| TR-state-010 | game-state-stage-flow.md | Foundation | Focus loss or backgrounding enters Paused: ticks stop, input cancels, the accumulator is zeroed, and a resume tap reaches nothing beneath | ADR-0003 | Covered (Proposed) |
| TR-state-011 | game-state-stage-flow.md | Foundation | One idempotent fatal handler keeps the first cause, overrides Won, Lost and Paused, latches, halts the tick and discards a partial build; the wrapper checks the latch after each assembly step; load failure, bad accessor call, a stage scene that fails to load and a null resolver create all reach it; the fatal screen is guaranteed to load | ADR-0001 | Covered (Proposed) |
| TR-state-012 | game-state-stage-flow.md | Foundation | Authored durations become whole ticks through one to_ticks conversion; countdowns are integer tick counters | ADR-0004 | Covered (Proposed) |
| TR-state-013 | game-state-stage-flow.md | Foundation | Tests can enumerate a battle's systems, inject recording fakes, snapshot a battle, and fail when any battle signal has no listener (views on an allowlist) | ADR-0007 | Covered (Proposed) |
| TR-state-014 | game-state-stage-flow.md | Foundation | Wrapper-side presentation timers (Lost delay, Won beat, button arming) run on the frame clock outside the simulation | ADR-0004 | Covered (Proposed) |
| TR-state-015 | game-state-stage-flow.md | Foundation | The battle holds a strong typed field for every helper build creates (each system, the FatalLatch, one StatAccessor per battle) and the builder holds nothing, because a method Callable or signal connection does not keep a RefCounted target alive and .call() on a dead one aborts the caller (observed on the 4.7.2 editor; export and phone unverified) | ADR-0001 (Decision 4, not in its table) | Covered (Proposed), implicit |
| TR-state-016 | game-state-stage-flow.md | Foundation | cancel_input() is a public Battle method guarded with is_valid(), set by the wrapper through set_input_cancel; Flow calls it on Won, Lost, Paused and Fatal and the app root before removing a battle on retry; it does nothing headless, and a second call finds the resolver Idle | ADR-0001 (Decision 10, not in its table) | Covered (Proposed), implicit |
| TR-combat-001 | combat-damage.md | Core | Combat is three pieces: a DamageEvent value (target, amount, source_kind, source_id), one Health and one Status per enemy; no ProjectileSpawner | ADR-0009 | Covered (Proposed) |
| TR-combat-002 | combat-damage.md | Core | The enemy object exposes spawn_id, cached distance and position, and removed, and stays a valid reference after removal, so it cannot be a freed Node | ADR-0009 | Covered (Proposed) |
| TR-combat-003 | combat-damage.md | Core | Every HP change goes through deliver(event) inside a tick, applying min(amount, hp) after guards in fixed order with named push_error codes | ADR-0009 | Covered (Proposed) |
| TR-combat-004 | combat-damage.md | Core | Death is immediate at HP 0 or below; dead enemies cannot be targeted; the reap step removes the corpse and emits enemy_killed(bounty) once | ADR-0009 | Covered (Proposed) |
| TR-combat-005 | combat-damage.md | Core | Per-source damage counters expose dealt_by_id, dealt_by_kind, dealt_total and hero_share, readable until the battle is destroyed | ADR-0009 | Covered (Proposed) |
| TR-combat-006 | combat-damage.md | Core | Slow is per-instance whole-tick countdown state with replace/equal/ignore rules; movement multiplies move_speed by speed_factor(enemy) | ADR-0009 | Covered (Proposed) |
| TR-combat-007 | combat-damage.md | Core | Combat reads no catalogue data; callers pass values in and its only dependency is the pure to_ticks with dt injected | ADR-0009 | Covered (Proposed) |
| TR-combat-008 | combat-damage.md | Core | Pure targeting helpers first_in, nearest_in and all_in_radius use an inclusive squared-distance test, tie-break by lowest spawn_id and never mutate input | ADR-0009 | Covered (Proposed) |
| TR-combat-009 | combat-damage.md | Core | Tick order is Flow, Enemy & Wave advance, tick_status, Towers by slot, Hero then burst, reap; leaks resolve before fire | ADR-0004 | Covered (Proposed) |
| TR-combat-010 | combat-damage.md | Core | View-only attack_fired and damage_applied emit after commit with copied positions; listeners never call deliver, and results match with or without listeners | ADR-0006 | Covered (Proposed) |
| TR-combat-011 | combat-damage.md | Core | The Combat view draws primitives from one _draw() per kind with no shaders or particles and a 16-marker flash pool on the frame clock | ADR-0011 | Covered (Proposed) |
| TR-combat-012 | combat-damage.md | Core | Errors use push_error, asserted with gdUnit4 assert_error().is_push_error() and the push_error report setting on; invariant I checks damage sums | ADR-0007 | Covered (Proposed) |
| TR-combat-013 | combat-damage.md | Core | Per-tick targeting stays within budget on a low-end phone at the catch-up clamp (about 400 range checks, under 2 ms, unmeasured) | ADR-0009 | Covered (Proposed) |
| TR-combat-014 | combat-damage.md | Core | Determinism holds per CPU architecture only; bot baselines are kept per architecture | ADR-0004 | Covered (Proposed) |
| TR-enemy-001 | enemy-wave.md | Core | The Stage record holds gameplay geometry (path_points, slot_positions, path_width, requires_bend, early_call_seconds_per_gold); the scene holds only the look | ADR-0002 | Covered (Proposed) |
| TR-enemy-002 | enemy-wave.md | Core | Fixed tick dt with one to_ticks (round half away from zero); spawn ticks come from an absolute schedule, never a float countdown | ADR-0004 | Covered (Proposed) |
| TR-enemy-003 | enemy-wave.md | Core | Enemy & Wave has two tick entries, advance (spawn, move, leak) and reap, in Combat's tick order; the battle passes the roster to tick_status | ADR-0004 | Covered (Proposed) |
| TR-enemy-004 | enemy-wave.md | Core | enemy_leaked, enemy_killed, wave_cleared and waves_complete fire synchronously (no CONNECT_DEFERRED) in spawn_id order after commit; leaks come before the clear | ADR-0006 | Covered (Proposed) |
| TR-enemy-005 | enemy-wave.md | Core | The builder injects a halted() callable checked after every accessor read and signal; the system never references Flow | ADR-0001 | Covered (Proposed) |
| TR-enemy-006 | enemy-wave.md | Core | Every enemy stat is read through the accessor at use time with a reused per-enemy read context; Wave and Stage records are read directly and never written | ADR-0005 | Covered (Proposed) |
| TR-enemy-007 | enemy-wave.md | Core | Waves use no randomness and never read the sim seed; cosmetic jitter uses a separate RNG; retry rebuilds identical spawn_id and schedule | ADR-0004 | Covered (Proposed) |
| TR-enemy-008 | enemy-wave.md | Core | The roster solely owns its enemies, exposes read-only roster() and targets() in spawn_id order, and enemies keep no back-references so retry frees them | ADR-0009 | Covered (Proposed) |
| TR-enemy-009 | enemy-wave.md | Core | How Health and Status attach to an enemy (spawn_id, def_id, distance, position, removed) is decided by ADR | ADR-0009 | Covered (Proposed) |
| TR-enemy-010 | enemy-wave.md | Core | Position comes from distance along a polyline via a cached cumulative-length array, crossing several segments per step and clamped to the end | ADR-0009 | Covered (Proposed) |
| TR-enemy-011 | enemy-wave.md | Core | An enemy is targetable only while its centre is inside the 540x960 field rectangle, a defined constant or injected value | ADR-0009 | Covered (Proposed) |
| TR-enemy-012 | enemy-wave.md | Core | Wave control is a Waiting/Active/Finished machine with start_next_wave() logging to an injected dev-error sink, not assert | ADR-0001 | Covered (Proposed) |
| TR-enemy-013 | enemy-wave.md | Core | One add-enemy step handles schedule spawns and future splitter children, joining atomically before the clear check | ADR-0009 | Covered (Proposed) |
| TR-enemy-014 | enemy-wave.md | Core | A headless content test checks layout rules L1-L14 and wave rules on in-memory records; unit tests use fakes and no scene or files | ADR-0007 | Covered (Proposed) |
| TR-enemy-015 | enemy-wave.md | Core | Views read roster() and the path each frame; fixed three-pass draw order; a view pool of at least 48 that grows with a dev error; Reduce Motion honoured | ADR-0011 | Covered (Proposed) |
| TR-enemy-016 | enemy-wave.md | Core | wave_index() is the 1-based position in wave_ids of the last wave started, 0 before any start and never reset per wave; Flow reads it for the result and the HUD for pips and result text | ADR-0001 names `wave_index()` as injected only; architecture.md assigns ADR-0009, which never names it | Partial |
| TR-enemy-017 | enemy-wave.md | Core | got_through_by_type() counts a leak before enemy_leaked fires, so a fatal leak is in the result | ADR-0010 names `got_through_by_type` as a log field only; architecture.md assigns ADR-0009, which never names it | Partial |
| TR-tower-001 | tower-system.md | Feature | TowerSim (builder-made, headless) holds gold, slots, towers and the tick; input objects (TowerInput and the HUD arc, wrapper-made, absent headless) change state only through TowerSim commands (upgrade, build) | ADR-0010 | Covered (Proposed) |
| TR-tower-002 | tower-system.md | Feature | build(slot_index, tower_id) and upgrade(slot_index) are the only mutation API, run between ticks and return a typed result enum in fixed check order | ADR-0010 | Covered (Proposed) |
| TR-tower-003 | tower-system.md | Feature | Tower IDs and levels are validated with is_tower and level_count before any accessor read; cost and stats are read at use time | ADR-0005 | Covered (Proposed) |
| TR-tower-004 | tower-system.md | Feature | Command commit is atomic: state commits before gold_changed then tower_built or tower_upgraded; a refusal changes and emits nothing | ADR-0006 | Covered (Proposed) |
| TR-tower-005 | tower-system.md | Feature | Towers tick in ascending slot index; cooldown_left is an integer tick counter that runs on every tick, Intermission included | ADR-0004 | Covered (Proposed) |
| TR-tower-006 | tower-system.md | Feature | The injected halted() is checked after every read and signal; all stats are read before any mutation so a bad read halts with nothing half done | ADR-0001 | Covered (Proposed) |
| TR-tower-007 | tower-system.md | Feature | Targeting and damage go only through Combat's API; splash victims come only from targets() | ADR-0009 | Covered (Proposed) |
| TR-tower-008 | tower-system.md | Feature | Gold is one non-negative integer owned by TowerSim, fed by starting_gold, enemy_killed(bounty) and wave_called_early; gold freezes once halted | ADR-0010 | Covered (Proposed) |
| TR-tower-009 | tower-system.md | Feature | The early-call bonus is one pure integer function early_call_bonus(seconds_left), to_ticks(seconds_left) div to_ticks(rate), shared by the payout and the HUD's Call +N; seconds_left includes the tick the next wave starts on | ADR-0010 | Covered (Proposed) |
| TR-tower-010 | tower-system.md | Feature | The upgrade chip window runs on real time while the sim clock is stopped, via a pure ChipWindow.advance(ms) fed by the wrapper | ADR-0004 | Covered (Proposed) |
| TR-tower-011 | tower-system.md | Feature | TowerInput registers slots and the chip disc with the resolver, disables built slots, closes the chip on phase, and ignores taps while halted | ADR-0008 | Covered (Proposed) |
| TR-tower-012 | tower-system.md | Feature | Signals have typed signatures (tower_id type undecided); gameplay may not depend on them and results match with or without listeners | ADR-0006 | Covered (Proposed) |
| TR-tower-013 | tower-system.md | Feature | Retry teardown leaves no old battle alive through a signal connection; a listener-count wiring test names any missing connection | ADR-0001 | Covered (Proposed) |
| TR-tower-014 | tower-system.md | Feature | All logic is unit-testable headless with spy accessor, recording fake and fake halted(); the content test enforces tower and gold rows | ADR-0007 | Covered (Proposed) |
| TR-tower-015 | tower-system.md | Feature | All towers draw from one _draw() node with primitive polygons, level inset and a cooldown ring, with Reduce Motion fallbacks | ADR-0011 | Covered (Proposed) |
| TR-hero-001 | hero-system.md | Feature | Hero splits into HeroSim (builder-made, headless) and HeroInput (wrapper-only), which changes battle state only through pin() and burst() | ADR-0010 | Covered (Proposed) |
| TR-hero-002 | hero-system.md | Feature | pin() and burst() run between ticks and return ordered enum result codes, state checked before geometry; a refusal mutates nothing | ADR-0010 | Covered (Proposed) |
| TR-hero-003 | hero-system.md | Feature | HeroSim ticks in the Hero-and-burst slot (walk, attack, cooldown, telegraph, release), uses to_ticks, and returns at once when halted() | ADR-0004 | Covered (Proposed) |
| TR-hero-004 | hero-system.md | Feature | The builder injects halted(), in_build(), the hand flag, the Hero record ID and burst_id into HeroSim; the wrapper, not the builder, injects them into HeroInput and the HUD, and the Burst ID into the HUD for the cooldown wedge | ADR-0001 | Covered (Proposed) |
| TR-hero-005 | hero-system.md | Feature | Hero and Burst stats are read through the accessor at use time; hero_start, pin_rect and pin_exclusion come straight from the Stage record | ADR-0005 | Covered (Proposed) |
| TR-hero-006 | hero-system.md | Feature | PinGeometry is a plain scene-free class computing in float scalars only (no Vector2 methods) with stated tolerances and tie-breaks | ADR-0004 | Covered (Proposed) |
| TR-hero-007 | hero-system.md | Feature | Hero uses deliver with HERO/BURST source kinds, report_attack before deliver, and nearest_in, all_in_radius, is_dead, hp_left over targets() | ADR-0009 | Covered (Proposed) |
| TR-hero-008 | hero-system.md | Feature | hero_pinned and burst_started emit after state is set and are on Flow's view allowlist; handlers never issue commands | ADR-0006 | Covered (Proposed) |
| TR-hero-009 | hero-system.md | Feature | HeroSim exposes read-only queries and per-run counters (repins, bursts, victims, kills) for HUD, bots, logs and Stage Progression | ADR-0010 | Covered (Proposed) |
| TR-hero-010 | hero-system.md | Feature | HeroInput registers hero DRAG, button DRAG and sink TAP discs, updates the walking hero's hit centre each frame, and hit-tests cancel hysteresis | ADR-0008 | Covered (Proposed) |
| TR-hero-011 | hero-system.md | Feature | HeroInput's aim state machine and cooldown_digit() advance through an explicit update(), not engine frames | ADR-0004 | Covered (Proposed) |
| TR-hero-012 | hero-system.md | Feature | A resolver-driven script and a direct-command script give tick-identical HeroSim state; a never-pinned run equals a HeroSim-absent run | ADR-0010 | Covered (Proposed) |
| TR-hero-013 | hero-system.md | Feature | Pause stops the sim clock so walk and telegraph resume exactly; aims get drag_cancelled; Build runs no ticks, so a pin in Build places the hero at once through in_build(); Intermission ticks | ADR-0004 | Covered (Proposed) |
| TR-hero-014 | hero-system.md | Feature | Content tests enforce hero and burst rules (leash, telegraph, intermission, reach, hero_start, pin_exclusion, one Hero record), each proven on a broken fixture | ADR-0002 | Covered (Proposed) |
| TR-hero-015 | hero-system.md | Feature | burst_button_centre() is owned by the HUD, read once by HeroInput at registration, and injectable by tests | ADR-0010 | Covered (Proposed) |
| TR-hud-001 | battle-hud.md | Presentation | The HUD is HudLogic (plain, the only part that decides, registers every HUD disc and issues every command), HudTopBand (display-only Controls), HudField (one _draw, no targets) and HudModals (result and Paused Controls), built before HeroInput, absent headless and rebuilt on retry | ADR-0011 | Covered (Proposed) |
| TR-hud-002 | battle-hud.md | Presentation | Result and Paused screens are full-screen modal Controls, built once and toggled visible, that consume presses (not moves or releases) before the Input adapter sees them; a modal is only hidden inside its own handler, never freed | ADR-0003 | Covered (Proposed) |
| TR-hud-003 | battle-hud.md | Presentation | HudLogic's modal press model repeats the adapter's rules: a press inside edge_reject_margin or an inset does not count, a tap counts only on the same pointer's release within tap_slop while Armed, a later press replaces an unmoved one, and lifecycle or focus-loss signals clear it | ADR-0003 | Covered (Proposed) |
| TR-hud-004 | battle-hud.md | Presentation | The HUD holds presentation state only and no reset path; full sim state is identical with or without the HUD | ADR-0006 | Covered (Proposed) |
| TR-hud-005 | battle-hud.md | Presentation | Each frame runs input commands, then real-time models, then ticks, then views, so the displayed bonus equals the paid bonus | ADR-0004 | Covered (Proposed) |
| TR-hud-006 | battle-hud.md | Presentation | Retry sets an idempotent latch on the app root and never frees its caller; the root's next frame checks Fatal, stops the Clock, cancels input through Battle.cancel_input(), frees and rebuilds | ADR-0001 | Covered (Proposed) |
| TR-hud-007 | battle-hud.md | Presentation | Armed buttons go Hidden, Arming, Armed on a real-time advance(ms) clock clamped to 100 ms and frozen while Paused | ADR-0004 | Covered (Proposed) |
| TR-hud-008 | battle-hud.md | Presentation | The build arc registers and unregisters resolver targets on open and close, disables Start/Call while open, and closes on outcome, Paused or Fatal | ADR-0008 | Covered (Proposed) |
| TR-hud-009 | battle-hud.md | Presentation | The resolver's pressed payload exposes both best_tap and best_drag so the HUD can ignore a Start/Call tap that also hits the hero | ADR-0008 | Covered (Proposed) |
| TR-hud-010 | battle-hud.md | Presentation | The HUD reads Flow, Tower, Hero, Enemy & Wave and Combat via signals and view-only queries (wave_index(), got_through_by_type(), chip_state(), early_call_bonus(), tower_inspected, hero_pinned, tower_built); the burst wedge is the float burst_wedge formula over cooldown_left() and Burst cooldown, read through the accessor with the injected Burst ID when Cooling begins; phase_changed and lives_changed join the view allowlist, which means they may have zero view connections in a headless build | ADR-0006 | Covered (Proposed) |
| TR-hud-011 | battle-hud.md | Presentation | Costs are read through the accessor on arc open and gold_changed; a read or snapshot that finds phase() Fatal is abandoned for the Fatal screen (halted() is not the test, since it is also true on Won and Lost) | ADR-0005 | Covered (Proposed) |
| TR-hud-012 | battle-hud.md | Presentation | The result screen and log come from one snapshot built on the first advance(ms) after the outcome, never inside the tick's signal stack; no snapshot is built if phase() is Fatal | ADR-0006 | Covered (Proposed) |
| TR-hud-013 | battle-hud.md | Presentation | Debug builds append JSON lines to user://run_log.jsonl through an injectable sink; a write failure is non-fatal and release builds never write | ADR-0010 | Covered (Proposed) |
| TR-hud-014 | battle-hud.md | Presentation | Layout is in 540x960 field units with safe-area insets converted to field units; burst_y = clamp(888 - I_bottom, 816, 888) | ADR-0003 | Covered (Proposed) |
| TR-hud-015 | battle-hud.md | Presentation | HUD budget about 8 (max 12) of 60 draw calls and at most 3 text draws; hit targets at least 72 units (48 dp), text at least 21 units | ADR-0011 | Covered (Proposed) |
| TR-hud-016 | battle-hud.md | Presentation | Content tests enforce HUD layout rules (slot bounds, clearances including the burst line at least edge_reject_margin + 48 from a side edge, at most 3 next-wave types, a next-try line per enemy type, an early-call bonus of at most 2 digits, 6 waves, 10 lives) | ADR-0002 | Covered (Proposed) |
| TR-hud-017 | battle-hud.md | Presentation | HudField redraws only when a quantised view-model key changes (wedge step, digit, bonus label, visible set), not every frame | ADR-0011 (redraw trigger table, not in its table) | Covered (Proposed), implicit |
| TR-hud-018 | battle-hud.md | Presentation | Each debug run-log record holds a launch ID, made once at boot, and the game build hash; the wrapper injects both into HudLogic and the logs (split from TR-hud-006) | ADR-0010 ("Build hash and launch ID", not in its table) | Covered (Proposed), implicit |

## Known Gaps

No requirement is without an ADR. Two are partial:

- **TR-enemy-016** (enemy-wave.md, Core): `wave_index()` is 1-based, 0 before any start and never reset. ADR-0001 lists it among the injected callables, but no ADR fixes its meaning. `architecture.md` v4 assigns it to ADR-0009, whose text never names it. Fix: add it to ADR-0009's Decision and table (or to ADR-0006), or change the assignment in `architecture.md`.
- **TR-enemy-017** (enemy-wave.md, Core): `got_through_by_type()` counts a leak before `enemy_leaked` fires. ADR-0010 lists the field in the run log only; no ADR fixes the count-before-emit order. `architecture.md` v4 assigns it to ADR-0009, whose text never names it. Fix: add the rule to ADR-0009 (add-enemy and leak step) or to ADR-0006 emit rules.

Four more are covered only in Decision text, missing from the covering ADR's GDD Requirements Addressed table: TR-state-015 and TR-state-016 (ADR-0001), TR-hud-017 (ADR-0011), TR-hud-018 (ADR-0010). Add the rows when each ADR is next revised.

## Superseded Requirements

No registry entry is superseded or deprecated. Three registry texts use names an ADR has since changed. The GDDs still use the old names too, so the registry follows its GDD until the GDD sync lands; then revise the text with a `revised` date (same IDs):

- TR-input-009: `tap`, `ground_tap`, `idle` became `tapped`, `ground_tapped`, `became_idle` (ADR-0008).
- TR-enemy-004: `waves_complete` became `waves_completed` (ADR-0006).
- TR-tower-012: "tower_id type undecided"; ADR-0006 decided `StringName`.

## History

| Date | Total | Accepted | Proposed | Partial | Gap | Notes |
|------|-------|----------|----------|---------|-----|-------|
| 2026-11-04 | 126 | 0 | 124 | 2 | 0 | First matrix against the 11 written ADRs; adds TR-hud-018; replaces the 125-row index |
