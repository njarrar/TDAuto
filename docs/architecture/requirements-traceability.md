# Architecture Traceability Index
Last Updated: 2026-11-04
Engine: Godot 4.7.2 (GDScript, Mobile renderer)

## Coverage Summary
- Total requirements: 125
- Covered: 0 (0%)
- Partial: 0
- Gaps: 125

No ADR exists yet (`docs/architecture/adr-*.md` matches nothing), so every
requirement is a gap. "Planned" names the proposed ADR in
`docs/architecture/architecture.md` (v3, ADR-0001 to ADR-0011) that will cover
it; the numbers are provisional until `/architecture-decision` assigns them.
The 2026-11-03 version of this index used review labels P01 to P15; the
architecture document maps them.

Changes in this run (2026-11-04, second review): TR-state-015, TR-state-016,
TR-enemy-017 and TR-hud-017 added; TR-data-005, TR-input-011, TR-input-012,
TR-input-015, TR-state-002, TR-state-006, TR-state-007, TR-state-011,
TR-tower-009, TR-hero-013, TR-hud-001, TR-hud-002, TR-hud-003, TR-hud-010,
TR-hud-011, TR-hud-012 and TR-hud-016 reworded after the Flow and Battle HUD
revisions (commit 9c81113) and Hero's Rule 2 amendment. No requirement was
deprecated. Earlier the same day: TR-enemy-016 added.

## Full Matrix
| Requirement ID | GDD | System | Layer | Requirement | ADR Coverage | Status |
|---|---|---|---|---|---|---|
| TR-data-001 | data-config-pipeline.md | Data & Config | Foundation | Typed read-only records keyed by a stable snake_case ID unique across all record types; records reference each other by typed ID, never by file path | — (planned: ADR-0002) | ❌ GAP |
| TR-data-002 | data-config-pipeline.md | Data & Config | Foundation | The storage format, or a check on top of it, detects a missing field, a fractional integer and an unknown property | — (planned: ADR-0002) | ❌ GAP |
| TR-data-003 | data-config-pipeline.md | Data & Config | Foundation | The catalogue loads from an explicit manifest of data files, never a directory scan, and loads correctly from an Android export | — (planned: ADR-0002) | ❌ GAP |
| TR-data-004 | data-config-pipeline.md | Data & Config | Foundation | Loading is once and all-or-nothing (Unloaded, Loading, Ready/Failed), started by the app root before the first gameplay scene, with no reload | — (planned: ADR-0001) | ❌ GAP |
| TR-data-005 (revised 2026-11-04) | data-config-pipeline.md | Data & Config | Foundation | The validator collects every error as {code, source, record_id, field} before failing, in tiers (manifest, finiteness, bounds, tags, references), and checks the Input record's cross-field tap_slop > drag_slop at load | — (planned: ADR-0002) | ❌ GAP |
| TR-data-006 | data-config-pipeline.md | Data & Config | Foundation | No fallbacks in any build; a load failure shows a catalogue-free fatal screen that never opens saves, and dev runs name each error | — (planned: ADR-0001) | ❌ GAP |
| TR-data-007 | data-config-pipeline.md | Data & Config | Foundation | Definitions are read-only after load and mutable state lives on runtime instances holding def_id; a deep-snapshot test proves the catalogue is unchanged after a battle | — (planned: ADR-0002) | ❌ GAP |
| TR-data-008 | data-config-pipeline.md | Data & Config | Foundation | Every modifiable value is read through one stat accessor (read_context, stat_key) at use time, never cached, so Stat & Modifier Resolution can replace its internals with no call-site change | — (planned: ADR-0005) | ❌ GAP |
| TR-data-009 | data-config-pipeline.md | Data & Config | Foundation | A bad accessor call goes to an injected, test-replaceable failure handler that survives release builds (not assert) | — (planned: ADR-0001) | ❌ GAP |
| TR-data-010 | data-config-pipeline.md | Data & Config | Foundation | Data owns the stat-key vocabulary and int/float type per key, and exposes non-fatal level_count(def_id) and is_tower(id) | — (planned: ADR-0005) | ❌ GAP |
| TR-data-011 | data-config-pipeline.md | Data & Config | Foundation | No autoload or global: the app root holds the Ready catalogue across retries and the battle builder injects it | — (planned: ADR-0001) | ❌ GAP |
| TR-data-012 | data-config-pipeline.md | Data & Config | Foundation | Logic tests build fixture catalogues in code with no file I/O; a separate integration suite validates the real data files | — (planned: ADR-0007) | ❌ GAP |
| TR-data-013 | data-config-pipeline.md | Data & Config | Foundation | A CI content test opens each Stage scene_ref, applies layout and wave rules, and checks rationale fields and owning-GDD balance ranges | — (planned: ADR-0002) | ❌ GAP |
| TR-data-014 | data-config-pipeline.md | Data & Config | Foundation | The data store emits no signals; each emitter declares its own and the composition root wires them | — (planned: ADR-0006) | ❌ GAP |
| TR-data-015 | data-config-pipeline.md | Data & Config | Foundation | Load-time targets: Loading to Ready median at most 1000 ms on an Adreno 5xx-class device; edit-to-in-game at most 10 s | — (planned: ADR-0002) | ❌ GAP |
| TR-input-001 | input-gesture-resolver.md | Input & Gesture | Foundation | The resolver is a pure, scene-free, clock-free object driven only by press, move, release, cancel_pointer and cancel | — (planned: ADR-0008) | ❌ GAP |
| TR-input-002 | input-gesture-resolver.md | Input & Gesture | Foundation | One thin adapter node is the only engine-facing input code; it maps Godot touch and mouse events to the five calls in 540x960 field units | — (planned: ADR-0003) | ❌ GAP |
| TR-input-003 | input-gesture-resolver.md | Input & Gesture | Foundation | Every forwarded press is followed by exactly one release or cancel for that index, even under a mouse_filter STOP Control; the canceled flag is honoured | — (planned: ADR-0003) | ❌ GAP |
| TR-input-004 | input-gesture-resolver.md | Input & Gesture | Foundation | The adapter runs PROCESS_MODE_ALWAYS and calls cancel() on app pause, focus loss and viewport resize, forwarding one lifecycle signal to Game State | — (planned: ADR-0003) | ❌ GAP |
| TR-input-005 | input-gesture-resolver.md | Input & Gesture | Foundation | Touch and mouse use one event family: emulation settings stop duplicate presses, the mouse pointer index never collides with touch index 0, non-left buttons are dropped | — (planned: ADR-0003) | ❌ GAP |
| TR-input-006 | input-gesture-resolver.md | Input & Gesture | Foundation | The adapter rejects presses inside edge_reject_margin and platform safe-area insets via DisplayServer.get_display_safe_area(), converted to field units | — (planned: ADR-0003) | ❌ GAP |
| TR-input-007 | input-gesture-resolver.md | Input & Gesture | Foundation | A registry of disc hit targets {id, centre, radius, accepts, priority, enabled, sink}; register, unregister, set_centre and set_enabled are legal in any state and apply at once | — (planned: ADR-0008) | ❌ GAP |
| TR-input-008 | input-gesture-resolver.md | Input & Gesture | Foundation | A four-state machine (Idle, Pressed, Dragging, Dead) with one active pointer freezes TAP and DRAG winners at press and classifies by per-press slop | — (planned: ADR-0008) | ❌ GAP |
| TR-input-009 | input-gesture-resolver.md | Input & Gesture | Foundation | Signal API pressed, tap, ground_tap, drag_started, drag_moved, drag_ended, drag_cancelled, idle; every exit to Idle emits idle() last | — (planned: ADR-0008) | ❌ GAP |
| TR-input-010 | input-gesture-resolver.md | Input & Gesture | Foundation | State commits before emit; gesture calls made inside a handler queue FIFO and drain synchronously in the outermost call | — (planned: ADR-0008) | ❌ GAP |
| TR-input-011 (revised 2026-11-04) | input-gesture-resolver.md | Input & Gesture | Foundation | Slops come by injection through static validate() and a create() factory returning null on bad input, and a null create() in the wrapper calls the failure handler; non-finite positions are dropped with push_error | — (planned: ADR-0008) | ❌ GAP |
| TR-input-012 (revised 2026-11-04) | input-gesture-resolver.md | Input & Gesture | Foundation | The battle wrapper builds the resolver and adapter per battle from the Input record and injects the one resolver into the Hero, Tower and HUD input objects; hit radii (36 to 56) are constants on those objects, not catalogue fields | — (planned: ADR-0001) | ❌ GAP |
| TR-input-013 | input-gesture-resolver.md | Input & Gesture | Presentation | Burst button, build arc and world targets are resolver discs, not Controls; HUD Controls consume their events before the adapter, so routing order is fixed | — (planned: ADR-0003) | ❌ GAP |
| TR-input-014 | input-gesture-resolver.md | Input & Gesture | Foundation | Identical call lists give identical signal logs; tests use a recording fake, not assert_signal; bots call commands directly plus one resolver equivalence test | — (planned: ADR-0007) | ❌ GAP |
| TR-input-015 (revised 2026-11-04) | input-gesture-resolver.md | Input & Gesture | Feature | Dev builds carry a gesture-log harness recording device, insets, timing, travel, winners and classification, listening to tower_upgraded, chip_state() at tower prompts and burst_started (only it counts as a burst), for the Pillar 4 phone test | — (planned: ADR-0008) | ❌ GAP |
| TR-input-016 | input-gesture-resolver.md | Input & Gesture | Foundation | Minimum width 360 dp by runtime guard; stretch mode keeps field units equal to viewport units, no Camera2D, and a cancel() on resize | — (planned: ADR-0003) | ❌ GAP |
| TR-state-001 | game-state-stage-flow.md | Game State & Flow | Foundation | A minimal main-scene app root with no autoload triggers the catalogue load, holds the Ready catalogue, owns the fatal screen, and alone survives a retry | — (planned: ADR-0001) | ❌ GAP |
| TR-state-002 (revised 2026-11-04) | game-state-stage-flow.md | Game State & Flow | Foundation | A scene-free builder build(catalogue, stage_id, seed, fatal_handler) wires every battle system by explicit signal connections and runs headless, calling the handler and returning null when the stage cannot be built; a thin wrapper adds tick loop, resolver, adapter and views | — (planned: ADR-0001) | ❌ GAP |
| TR-state-003 | game-state-stage-flow.md | Game State & Flow | Foundation | Simulation time enters only through battle.tick(dt) at a fixed rate; no _process, Timers, await, wall clock or physics areas in gameplay; the wrapper clamps owed ticks | — (planned: ADR-0004) | ❌ GAP |
| TR-state-004 | game-state-stage-flow.md | Game State & Flow | Foundation | Systems tick in one fixed documented order and player and bot commands apply only between ticks | — (planned: ADR-0004) | ❌ GAP |
| TR-state-005 | game-state-stage-flow.md | Game State & Flow | Foundation | All randomness comes from an injected seed so stage, seed and command script give an identical result | — (planned: ADR-0004) | ❌ GAP |
| TR-state-006 (revised 2026-11-04) | game-state-stage-flow.md | Game State & Flow | Core | Flow and lives are a pure stage state machine (Build, Wave, Intermission, Paused, Won, Lost, and Fatal as an absorbing state) with a result readable after the outcome; in_build() is true in Build and in Paused from Build; last wave started is Enemy & Wave's wave_index() | — (planned: ADR-0004) | ❌ GAP |
| TR-state-007 (revised 2026-11-04) | game-state-stage-flow.md | Game State & Flow | Core | Every transition commits state, then acts, then emits in a fixed order, and stops emitting if Fatal latched during an emit; phase fires on every state change; Won, Lost, Paused and Fatal stop the clock and cancel input before they emit; remaining systems skip the rest of that tick | — (planned: ADR-0004) | ❌ GAP |
| TR-state-008 | game-state-stage-flow.md | Game State & Flow | Core | Flow listens to synchronous wave_cleared, waves_complete and enemy_leaked (leak before complete) and emits lives_changed, phase and wave_called_early | — (planned: ADR-0006) | ❌ GAP |
| TR-state-009 | game-state-stage-flow.md | Game State & Flow | Foundation | Retry destroys the whole battle and builds a new one between ticks, driven by a latch on the app root; a weakref to the old battle must be null | — (planned: ADR-0001) | ❌ GAP |
| TR-state-010 | game-state-stage-flow.md | Game State & Flow | Foundation | Focus loss or backgrounding enters Paused: ticks stop, input cancels, the accumulator is zeroed, and a resume tap reaches nothing beneath | — (planned: ADR-0003) | ❌ GAP |
| TR-state-011 (revised 2026-11-04) | game-state-stage-flow.md | Game State & Flow | Foundation | One idempotent fatal handler keeps the first cause, overrides Won, Lost and Paused, latches, halts the tick and discards a partial build; the wrapper checks the latch after each assembly step; load failure, bad accessor call, a stage scene that fails to load and a null resolver create all reach it; the fatal screen is guaranteed to load | — (planned: ADR-0001) | ❌ GAP |
| TR-state-012 | game-state-stage-flow.md | Game State & Flow | Core | Authored durations become whole ticks through one to_ticks conversion; countdowns are integer tick counters | — (planned: ADR-0004) | ❌ GAP |
| TR-state-013 | game-state-stage-flow.md | Game State & Flow | Foundation | Tests can enumerate a battle's systems, inject recording fakes, snapshot a battle, and fail when any battle signal has no listener (views on an allowlist) | — (planned: ADR-0007) | ❌ GAP |
| TR-state-014 | game-state-stage-flow.md | Game State & Flow | Presentation | Wrapper-side presentation timers (Lost delay, Won beat, button arming) run on the frame clock outside the simulation | — (planned: ADR-0004) | ❌ GAP |
| TR-state-015 (new 2026-11-04) | game-state-stage-flow.md | Game State & Flow | Foundation | The battle holds a strong typed field for every helper build creates (each system, the FatalLatch, one StatAccessor per battle) and the builder holds nothing, because a method Callable or signal connection does not keep a RefCounted target alive and .call() on a dead one aborts the caller (observed on the 4.7.2 editor; export and phone unverified) | — (planned: ADR-0001) | ❌ GAP |
| TR-state-016 (new 2026-11-04) | game-state-stage-flow.md | Game State & Flow | Foundation | cancel_input() is a public Battle method guarded with is_valid(), set by the wrapper through set_input_cancel; Flow calls it on Won, Lost, Paused and Fatal and the app root before removing a battle on retry; it does nothing headless, and a second call finds the resolver Idle | — (planned: ADR-0001) | ❌ GAP |
| TR-combat-001 | combat-damage.md | Combat & Damage | Core | Combat is three pieces: a DamageEvent value (target, amount, source_kind, source_id), one Health and one Status per enemy; no ProjectileSpawner | — (planned: ADR-0009) | ❌ GAP |
| TR-combat-002 | combat-damage.md | Combat & Damage | Core | The enemy object exposes spawn_id, cached distance and position, and removed, and stays a valid reference after removal, so it cannot be a freed Node | — (planned: ADR-0009) | ❌ GAP |
| TR-combat-003 | combat-damage.md | Combat & Damage | Core | Every HP change goes through deliver(event) inside a tick, applying min(amount, hp) after guards in fixed order with named push_error codes | — (planned: ADR-0009) | ❌ GAP |
| TR-combat-004 | combat-damage.md | Combat & Damage | Core | Death is immediate at HP 0 or below; dead enemies cannot be targeted; the reap step removes the corpse and emits enemy_killed(bounty) once | — (planned: ADR-0009) | ❌ GAP |
| TR-combat-005 | combat-damage.md | Combat & Damage | Core | Per-source damage counters expose dealt_by_id, dealt_by_kind, dealt_total and hero_share, readable until the battle is destroyed | — (planned: ADR-0009) | ❌ GAP |
| TR-combat-006 | combat-damage.md | Combat & Damage | Core | Slow is per-instance whole-tick countdown state with replace/equal/ignore rules; movement multiplies move_speed by speed_factor(enemy) | — (planned: ADR-0009) | ❌ GAP |
| TR-combat-007 | combat-damage.md | Combat & Damage | Core | Combat reads no catalogue data; callers pass values in and its only dependency is the pure to_ticks with dt injected | — (planned: ADR-0009) | ❌ GAP |
| TR-combat-008 | combat-damage.md | Combat & Damage | Core | Pure targeting helpers first_in, nearest_in and all_in_radius use an inclusive squared-distance test, tie-break by lowest spawn_id and never mutate input | — (planned: ADR-0009) | ❌ GAP |
| TR-combat-009 | combat-damage.md | Combat & Damage | Foundation | Tick order is Flow, Enemy & Wave advance, tick_status, Towers by slot, Hero then burst, reap; leaks resolve before fire | — (planned: ADR-0004) | ❌ GAP |
| TR-combat-010 | combat-damage.md | Combat & Damage | Core | View-only attack_fired and damage_applied emit after commit with copied positions; listeners never call deliver, and results match with or without listeners | — (planned: ADR-0006) | ❌ GAP |
| TR-combat-011 | combat-damage.md | Combat & Damage | Presentation | The Combat view draws primitives from one _draw() per kind with no shaders or particles and a 16-marker flash pool on the frame clock | — (planned: ADR-0011) | ❌ GAP |
| TR-combat-012 | combat-damage.md | Combat & Damage | Foundation | Errors use push_error, asserted with gdUnit4 assert_error().is_push_error() and the push_error report setting on; invariant I checks damage sums | — (planned: ADR-0007) | ❌ GAP |
| TR-combat-013 | combat-damage.md | Combat & Damage | Core | Per-tick targeting stays within budget on a low-end phone at the catch-up clamp (about 400 range checks, under 2 ms, unmeasured) | — (planned: ADR-0009) | ❌ GAP |
| TR-combat-014 | combat-damage.md | Combat & Damage | Foundation | Determinism holds per CPU architecture only; bot baselines are kept per architecture | — (planned: ADR-0004) | ❌ GAP |
| TR-enemy-001 | enemy-wave.md | Enemy & Wave | Foundation | The Stage record holds gameplay geometry (path_points, slot_positions, path_width, requires_bend, early_call_seconds_per_gold); the scene holds only the look | — (planned: ADR-0002) | ❌ GAP |
| TR-enemy-002 | enemy-wave.md | Enemy & Wave | Foundation | Fixed tick dt with one to_ticks (round half away from zero); spawn ticks come from an absolute schedule, never a float countdown | — (planned: ADR-0004) | ❌ GAP |
| TR-enemy-003 | enemy-wave.md | Enemy & Wave | Core | Enemy & Wave has two tick entries, advance (spawn, move, leak) and reap, in Combat's tick order; the battle passes the roster to tick_status | — (planned: ADR-0004) | ❌ GAP |
| TR-enemy-004 | enemy-wave.md | Enemy & Wave | Core | enemy_leaked, enemy_killed, wave_cleared and waves_complete fire synchronously (no CONNECT_DEFERRED) in spawn_id order after commit; leaks come before the clear | — (planned: ADR-0006) | ❌ GAP |
| TR-enemy-005 | enemy-wave.md | Enemy & Wave | Core | The builder injects a halted() callable checked after every accessor read and signal; the system never references Flow | — (planned: ADR-0001) | ❌ GAP |
| TR-enemy-006 | enemy-wave.md | Enemy & Wave | Foundation | Every enemy stat is read through the accessor at use time with a reused per-enemy read context; Wave and Stage records are read directly and never written | — (planned: ADR-0005) | ❌ GAP |
| TR-enemy-007 | enemy-wave.md | Enemy & Wave | Foundation | Waves use no randomness and never read the sim seed; cosmetic jitter uses a separate RNG; retry rebuilds identical spawn_id and schedule | — (planned: ADR-0004) | ❌ GAP |
| TR-enemy-008 | enemy-wave.md | Enemy & Wave | Core | The roster solely owns its enemies, exposes read-only roster() and targets() in spawn_id order, and enemies keep no back-references so retry frees them | — (planned: ADR-0009) | ❌ GAP |
| TR-enemy-009 | enemy-wave.md | Enemy & Wave | Core | How Health and Status attach to an enemy (spawn_id, def_id, distance, position, removed) is decided by ADR | — (planned: ADR-0009) | ❌ GAP |
| TR-enemy-010 | enemy-wave.md | Enemy & Wave | Core | Position comes from distance along a polyline via a cached cumulative-length array, crossing several segments per step and clamped to the end | — (planned: ADR-0009) | ❌ GAP |
| TR-enemy-011 | enemy-wave.md | Enemy & Wave | Core | An enemy is targetable only while its centre is inside the 540x960 field rectangle, a defined constant or injected value | — (planned: ADR-0009) | ❌ GAP |
| TR-enemy-012 | enemy-wave.md | Enemy & Wave | Core | Wave control is a Waiting/Active/Finished machine with start_next_wave() logging to an injected dev-error sink, not assert | — (planned: ADR-0001) | ❌ GAP |
| TR-enemy-013 | enemy-wave.md | Enemy & Wave | Core | One add-enemy step handles schedule spawns and future splitter children, joining atomically before the clear check | — (planned: ADR-0009) | ❌ GAP |
| TR-enemy-014 | enemy-wave.md | Enemy & Wave | Foundation | A headless content test checks layout rules L1-L14 and wave rules on in-memory records; unit tests use fakes and no scene or files | — (planned: ADR-0007) | ❌ GAP |
| TR-enemy-015 | enemy-wave.md | Enemy & Wave | Presentation | Views read roster() and the path each frame; fixed three-pass draw order; a view pool of at least 48 that grows with a dev error; Reduce Motion honoured | — (planned: ADR-0011) | ❌ GAP |
| TR-enemy-016 | enemy-wave.md | Enemy & Wave | Core | wave_index() is the 1-based position in wave_ids of the last wave started, 0 before any start and never reset per wave; Flow reads it for the result and the HUD for pips and result text | — (planned: ADR-0009) | ❌ GAP |
| TR-enemy-017 (new 2026-11-04) | enemy-wave.md | Enemy & Wave | Core | got_through_by_type() counts a leak before enemy_leaked fires, so a fatal leak is in the result | — (planned: ADR-0009) | ❌ GAP |
| TR-tower-001 | tower-system.md | Tower | Core | TowerSim (builder-made, headless) holds gold, slots, towers and the tick; TowerInput (wrapper-made, absent headless) changes state only through upgrade | — (planned: ADR-0010) | ❌ GAP |
| TR-tower-002 | tower-system.md | Tower | Core | build(slot_index, tower_id) and upgrade(slot_index) are the only mutation API, run between ticks and return a typed result enum in fixed check order | — (planned: ADR-0010) | ❌ GAP |
| TR-tower-003 | tower-system.md | Tower | Foundation | Tower IDs and levels are validated with is_tower and level_count before any accessor read; cost and stats are read at use time | — (planned: ADR-0005) | ❌ GAP |
| TR-tower-004 | tower-system.md | Tower | Core | Command commit is atomic: state commits before gold_changed then tower_built or tower_upgraded; a refusal changes and emits nothing | — (planned: ADR-0006) | ❌ GAP |
| TR-tower-005 | tower-system.md | Tower | Core | Towers tick in ascending slot index; cooldown_left is an integer tick counter that runs on every tick, Intermission included | — (planned: ADR-0004) | ❌ GAP |
| TR-tower-006 | tower-system.md | Tower | Core | The injected halted() is checked after every read and signal; all stats are read before any mutation so a bad read halts with nothing half done | — (planned: ADR-0001) | ❌ GAP |
| TR-tower-007 | tower-system.md | Tower | Core | Targeting and damage go only through Combat's API; splash victims come only from targets() | — (planned: ADR-0009) | ❌ GAP |
| TR-tower-008 | tower-system.md | Tower | Core | Gold is one non-negative integer owned by TowerSim, fed by starting_gold, enemy_killed(bounty) and wave_called_early; gold freezes once halted | — (planned: ADR-0010) | ❌ GAP |
| TR-tower-009 (revised 2026-11-04) | tower-system.md | Tower | Core | The early-call bonus is one pure integer function early_call_bonus(seconds_left), to_ticks(seconds_left) div to_ticks(rate), shared by the payout and the HUD's Call +N; seconds_left includes the tick the next wave starts on | — (planned: ADR-0010) | ❌ GAP |
| TR-tower-010 | tower-system.md | Tower | Feature | The upgrade chip window runs on real time while the sim clock is stopped, via a pure ChipWindow.advance(ms) fed by the wrapper | — (planned: ADR-0004) | ❌ GAP |
| TR-tower-011 | tower-system.md | Tower | Feature | TowerInput registers slots and the chip disc with the resolver, disables built slots, closes the chip on phase, and ignores taps while halted | — (planned: ADR-0008) | ❌ GAP |
| TR-tower-012 | tower-system.md | Tower | Core | Signals have typed signatures (tower_id type undecided); gameplay may not depend on them and results match with or without listeners | — (planned: ADR-0006) | ❌ GAP |
| TR-tower-013 | tower-system.md | Tower | Core | Retry teardown leaves no old battle alive through a signal connection; a listener-count wiring test names any missing connection | — (planned: ADR-0001) | ❌ GAP |
| TR-tower-014 | tower-system.md | Tower | Foundation | All logic is unit-testable headless with spy accessor, recording fake and fake halted(); the content test enforces tower and gold rows | — (planned: ADR-0007) | ❌ GAP |
| TR-tower-015 | tower-system.md | Tower | Presentation | All towers draw from one _draw() node with primitive polygons, level inset and a cooldown ring, with Reduce Motion fallbacks | — (planned: ADR-0011) | ❌ GAP |
| TR-hero-001 | hero-system.md | Hero | Core | Hero splits into HeroSim (builder-made, headless) and HeroInput (wrapper-only), which changes battle state only through pin() and burst() | — (planned: ADR-0010) | ❌ GAP |
| TR-hero-002 | hero-system.md | Hero | Core | pin() and burst() run between ticks and return ordered enum result codes, state checked before geometry; a refusal mutates nothing | — (planned: ADR-0010) | ❌ GAP |
| TR-hero-003 | hero-system.md | Hero | Core | HeroSim ticks in the Hero-and-burst slot (walk, attack, cooldown, telegraph, release), uses to_ticks, and returns at once when halted() | — (planned: ADR-0004) | ❌ GAP |
| TR-hero-004 (revised 2026-11-04) | hero-system.md | Hero | Core | The builder injects halted(), in_build(), the hand flag, the Hero record ID and burst_id into HeroSim, HeroInput and the HUD, and the Burst ID into the HUD for the cooldown wedge | — (planned: ADR-0001) | ❌ GAP |
| TR-hero-005 | hero-system.md | Hero | Foundation | Hero and Burst stats are read through the accessor at use time; hero_start, pin_rect and pin_exclusion come straight from the Stage record | — (planned: ADR-0005) | ❌ GAP |
| TR-hero-006 | hero-system.md | Hero | Core | PinGeometry is a plain scene-free class computing in float scalars only (no Vector2 methods) with stated tolerances and tie-breaks | — (planned: ADR-0004) | ❌ GAP |
| TR-hero-007 | hero-system.md | Hero | Core | Hero uses deliver with HERO/BURST source kinds, report_attack before deliver, and nearest_in, all_in_radius, is_dead, hp_left over targets() | — (planned: ADR-0009) | ❌ GAP |
| TR-hero-008 | hero-system.md | Hero | Core | hero_pinned and burst_started emit after state is set and are on Flow's view allowlist; handlers never issue commands | — (planned: ADR-0006) | ❌ GAP |
| TR-hero-009 | hero-system.md | Hero | Core | HeroSim exposes read-only queries and per-run counters (repins, bursts, victims, kills) for HUD, bots, logs and Stage Progression | — (planned: ADR-0010) | ❌ GAP |
| TR-hero-010 | hero-system.md | Hero | Presentation | HeroInput registers hero DRAG, button DRAG and sink TAP discs, updates the walking hero's hit centre each frame, and hit-tests cancel hysteresis | — (planned: ADR-0008) | ❌ GAP |
| TR-hero-011 | hero-system.md | Hero | Presentation | HeroInput's aim state machine and cooldown_digit() advance through an explicit update(), not engine frames | — (planned: ADR-0004) | ❌ GAP |
| TR-hero-012 | hero-system.md | Hero | Core | A resolver-driven script and a direct-command script give tick-identical HeroSim state; a never-pinned run equals a HeroSim-absent run | — (planned: ADR-0010) | ❌ GAP |
| TR-hero-013 (revised 2026-11-04) | hero-system.md | Hero | Core | Pause stops the sim clock so walk and telegraph resume exactly; aims get drag_cancelled; Build runs no ticks, so a pin in Build places the hero at once through in_build(); Intermission ticks | — (planned: ADR-0004) | ❌ GAP |
| TR-hero-014 | hero-system.md | Hero | Foundation | Content tests enforce hero and burst rules (leash, telegraph, intermission, reach, hero_start, pin_exclusion, one Hero record), each proven on a broken fixture | — (planned: ADR-0002) | ❌ GAP |
| TR-hero-015 | hero-system.md | Hero | Presentation | burst_button_centre() is owned by the HUD, read once by HeroInput at registration, and injectable by tests | — (planned: ADR-0010) | ❌ GAP |
| TR-hud-001 (revised 2026-11-04) | battle-hud.md | Battle HUD | Presentation | The HUD is HudLogic (plain, the only part that decides, registers every HUD disc and issues every command), HudTopBand (display-only Controls), HudField (one _draw, no targets) and HudModals (result and Paused Controls), built before HeroInput, absent headless and rebuilt on retry | — (planned: ADR-0011) | ❌ GAP |
| TR-hud-002 (revised 2026-11-04) | battle-hud.md | Battle HUD | Presentation | Result and Paused screens are full-screen modal Controls, built once and toggled visible, that consume every event before the Input adapter sees it; a modal is only hidden inside its own handler, never freed | — (planned: ADR-0003) | ❌ GAP |
| TR-hud-003 (revised 2026-11-04) | battle-hud.md | Battle HUD | Presentation | HudLogic's modal press model repeats the adapter's rules: a press inside edge_reject_margin or an inset does not count, a tap counts only on the same pointer's release within tap_slop while Armed, a later press replaces an unmoved one, and lifecycle or focus-loss signals clear it | — (planned: ADR-0003) | ❌ GAP |
| TR-hud-004 | battle-hud.md | Battle HUD | Presentation | The HUD holds presentation state only and no reset path; full sim state is identical with or without the HUD | — (planned: ADR-0006) | ❌ GAP |
| TR-hud-005 | battle-hud.md | Battle HUD | Core | Each frame runs input commands, then real-time models, then ticks, then views, so the displayed bonus equals the paid bonus | — (planned: ADR-0004) | ❌ GAP |
| TR-hud-006 | battle-hud.md | Battle HUD | Foundation | Retry sets an idempotent latch on the app root and never frees its caller; the root's next frame checks Fatal, stops, cancels, frees and rebuilds | — (planned: ADR-0001) | ❌ GAP |
| TR-hud-007 | battle-hud.md | Battle HUD | Presentation | Armed buttons go Hidden, Arming, Armed on a real-time advance(ms) clock clamped to 100 ms and frozen while Paused | — (planned: ADR-0004) | ❌ GAP |
| TR-hud-008 | battle-hud.md | Battle HUD | Presentation | The build arc registers and unregisters resolver targets on open and close, disables Start/Call while open, and closes on outcome, Paused or Fatal | — (planned: ADR-0008) | ❌ GAP |
| TR-hud-009 | battle-hud.md | Battle HUD | Presentation | The resolver's pressed payload exposes both best_tap and best_drag so the HUD can ignore a Start/Call tap that also hits the hero | — (planned: ADR-0008) | ❌ GAP |
| TR-hud-010 (revised 2026-11-04) | battle-hud.md | Battle HUD | Presentation | The HUD reads Flow, Tower, Hero, Enemy & Wave and Combat via signals and view-only queries (wave_index(), got_through_by_type(), chip_state(), early_call_bonus(), tower_inspected, hero_pinned, tower_built); the burst wedge is the float burst_wedge formula over cooldown_left() and Burst cooldown, read through the accessor with the injected Burst ID when Cooling begins; phase and lives_changed join the view allowlist | — (planned: ADR-0006) | ❌ GAP |
| TR-hud-011 (revised 2026-11-04) | battle-hud.md | Battle HUD | Presentation | Costs are read through the accessor on arc open and gold_changed; a read or snapshot that finds phase() Fatal is abandoned for the Fatal screen (halted() is not the test, since it is also true on Won and Lost) | — (planned: ADR-0005) | ❌ GAP |
| TR-hud-012 (revised 2026-11-04) | battle-hud.md | Battle HUD | Presentation | The result screen and log come from one snapshot built on the first advance(ms) after the outcome, never inside the tick's signal stack; no snapshot is built if phase() is Fatal | — (planned: ADR-0006) | ❌ GAP |
| TR-hud-013 | battle-hud.md | Battle HUD | Foundation | Debug builds append JSON lines to user://run_log.jsonl through an injectable sink; a write failure is non-fatal and release builds never write | — (planned: ADR-0010) | ❌ GAP |
| TR-hud-014 | battle-hud.md | Battle HUD | Presentation | Layout is in 540x960 field units with safe-area insets converted to field units; burst_y = clamp(888 - I_bottom, 816, 888) | — (planned: ADR-0003) | ❌ GAP |
| TR-hud-015 | battle-hud.md | Battle HUD | Presentation | HUD budget about 8 (max 12) of 60 draw calls and at most 3 text draws; hit targets at least 72 units (48 dp), text at least 21 units | — (planned: ADR-0011) | ❌ GAP |
| TR-hud-016 (revised 2026-11-04) | battle-hud.md | Battle HUD | Foundation | Content tests enforce HUD layout rules (slot bounds, clearances including the burst line at least edge_reject_margin + 48 from a side edge, at most 3 next-wave types, a next-try line per enemy type, an early-call bonus of at most 2 digits, 6 waves, 10 lives) | — (planned: ADR-0002) | ❌ GAP |
| TR-hud-017 (new 2026-11-04) | battle-hud.md | Battle HUD | Presentation | HudField redraws only when a quantised view-model key changes (every value its draw reads, including open-disc and chip affordability) and while a timed visual runs, not every frame | — (planned: ADR-0011) | ❌ GAP |

## Known Gaps
#### ADR-0001 (proposed). App Lifecycle, Composition Root and Fatal Path (Foundation, engine risk HIGH)

Suggested: `/architecture-decision "App Lifecycle, Composition Root and Fatal Path"`. Decides: no autoloads, AppRoot states (Boot, InStage, Fatal), scene-free builder, injected callables (method Callables only, no capturing lambdas or bind), per-battle FatalLatch, push_error vs assert, dev-error sink, retry by dropping references and the weakref proof, free() vs queue_free() timing, Reduce Motion location.

Requirements (17): TR-data-004, TR-data-006, TR-data-009, TR-data-011, TR-input-012, TR-state-001, TR-state-002, TR-state-009, TR-state-011, TR-enemy-005, TR-enemy-012, TR-tower-006, TR-tower-013, TR-hero-004, TR-hud-006, TR-state-015, TR-state-016

#### ADR-0002 (proposed). Catalogue Storage Format, Manifest and Validation (Foundation, engine risk HIGH)

Suggested: `/architecture-decision "Catalogue Storage Format, Manifest and Validation"`. Decides: Resource vs JSON, record classes, strict field checks, manifest load proven on an Android export, read-only proof with duplicate_deep, content tests.

Requirements (10): TR-data-001, TR-data-002, TR-data-003, TR-data-005, TR-data-007, TR-data-013, TR-data-015, TR-enemy-001, TR-hero-014, TR-hud-016

#### ADR-0003 (proposed). Input Adapter, Display Stretch and Platform Lifecycle (Foundation, engine risk HIGH)

Suggested: `/architecture-decision "Input Adapter, Display Stretch and Platform Lifecycle"`. Decides: engine event path and its order against _process and Controls (a spike first), touch and mouse emulation, 4.7 device IDs, safe area, stretch mode and aspect, minimum width, tall-phone behaviour, pause and focus notifications per platform; decided here, inherited later by the Mobile Platform GDD.

Requirements (11): TR-input-002, TR-input-003, TR-input-004, TR-input-005, TR-input-006, TR-input-013, TR-input-016, TR-state-010, TR-hud-002, TR-hud-003, TR-hud-014

#### ADR-0004 (proposed). Fixed-Tick Clock, Tick Order, Frame Order and Determinism (Foundation, engine risk HIGH)

Suggested: `/architecture-decision "Fixed-Tick Clock, Tick Order, Frame Order and Determinism"`. Decides: tick driver and rate, clamp value and max ticks per frame, the one tick order, commands between ticks, the in-sim clock gate, real-time presentation clocks, seeded RNG and cosmetic RNG split, float policy and per-architecture baselines, frame budget split.

Requirements (20): TR-state-003, TR-state-004, TR-state-005, TR-state-006, TR-state-007, TR-state-012, TR-state-014, TR-combat-009, TR-combat-014, TR-enemy-002, TR-enemy-003, TR-enemy-007, TR-tower-005, TR-tower-010, TR-hero-003, TR-hero-006, TR-hero-011, TR-hero-013, TR-hud-005, TR-hud-007

#### ADR-0005 (proposed). Stat Accessor and Read-Context Contract (Foundation, engine risk LOW)

Suggested: `/architecture-decision "Stat Accessor and Read-Context Contract"`. Decides: stat_int and stat_float, ReadContext reuse per caller, key vocabulary and types, non-fatal lookups.

Requirements (6): TR-data-008, TR-data-010, TR-enemy-006, TR-tower-003, TR-hero-005, TR-hud-011

#### ADR-0006 (proposed). Battle Signal Contracts and View Allowlist (Foundation, engine risk MEDIUM)

Suggested: `/architecture-decision "Battle Signal Contracts and View Allowlist"`. Decides: synchronous emit, commit before emit, final signal names (QQ-07) and payloads, ID types, view allowlist.

Requirements (10): TR-data-014, TR-state-008, TR-combat-010, TR-enemy-004, TR-tower-004, TR-tower-012, TR-hero-008, TR-hud-004, TR-hud-010, TR-hud-012

#### ADR-0007 (proposed). Headless Test Harness, gdUnit4 and Layer Lint (Foundation, engine risk MEDIUM)

Suggested: `/architecture-decision "Headless Test Harness, gdUnit4 and Layer Lint"`. Decides: fixtures, recording fakes that assert payloads, listener-count test, push_error reporting, layer-import lint, the manual-evidence list for what cannot run headless, GDScript 4.7 pitfalls for the control manifest.

Requirements (6): TR-data-012, TR-input-014, TR-state-013, TR-combat-012, TR-enemy-014, TR-tower-014

#### ADR-0008 (proposed). Input Resolver Core and Signal Contract (Foundation, engine risk MEDIUM)

Suggested: `/architecture-decision "Input Resolver Core and Signal Contract"`. Decides: pure resolver, hit-target registry, state machine, re-entrancy queue, payloads, gesture log.

Requirements (11): TR-input-001, TR-input-007, TR-input-008, TR-input-009, TR-input-010, TR-input-011, TR-input-015, TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009

#### ADR-0009 (proposed). Enemy Entity, Roster and Combat API (Core, engine risk MEDIUM)

Suggested: `/architecture-decision "Enemy Entity, Roster and Combat API"`. Decides: Targetable base class, Health and Status attachment, roster ownership and typed lists, path lookup, deliver guards, targeting helpers, per-tick budget.

Requirements (18): TR-combat-001, TR-combat-002, TR-combat-003, TR-combat-004, TR-combat-005, TR-combat-006, TR-combat-007, TR-combat-008, TR-combat-013, TR-enemy-008, TR-enemy-009, TR-enemy-010, TR-enemy-011, TR-enemy-013, TR-enemy-016, TR-tower-007, TR-hero-007, TR-enemy-017

#### ADR-0010 (proposed). Sim/Input Split, Command Result Codes and Dev Telemetry (Core, engine risk LOW)

Suggested: `/architecture-decision "Sim/Input Split, Command Result Codes and Dev Telemetry"`. Decides: HeroSim/TowerSim vs HeroInput/TowerInput, result enums with OK = 0, gold ownership, bot equivalence, run counters and run log.

Requirements (10): TR-tower-001, TR-tower-002, TR-tower-008, TR-tower-009, TR-hero-001, TR-hero-002, TR-hero-009, TR-hero-012, TR-hero-015, TR-hud-013

#### ADR-0011 (proposed). Battle Field Rendering and Draw-Call Budget (Presentation, engine risk MEDIUM)

Suggested: `/architecture-decision "Battle Field Rendering and Draw-Call Budget"`. Decides: single _draw nodes, pools, draw order, path polygon, HUD draw budget, hit-flash shader question.

Requirements (6): TR-combat-011, TR-enemy-015, TR-tower-015, TR-hud-001, TR-hud-015, TR-hud-017

## Superseded Requirements
None. No ADR has been written, so no GDD has changed after an ADR.
