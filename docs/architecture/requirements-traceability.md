# Architecture Traceability Index
Last Updated: 2026-11-03 (second review)
Engine: Godot 4.7.2 (GDScript, Mobile renderer)

## Coverage Summary
- Total requirements: 121
- Covered: 0 (0%)
- Covered (Proposed): 0
- Partial: 0
- Gaps: 121

No ADR exists yet (`docs/architecture/adr-*.md` matches nothing), so every
requirement is a gap. The ADR column names the ADR that `docs/architecture/architecture.md`
proposes for each requirement. Those numbers are provisional until
`/architecture-decision` assigns them. The first review's P01 to P15 labels map
to them in `architecture.md` § Required ADRs.

## Full Matrix
| Requirement ID | GDD | System | Layer | Requirement | ADR Coverage | Status |
|---|---|---|---|---|---|---|
| TR-data-001 | data-config-pipeline.md | Data & Config | Foundation | Typed read-only records keyed by a stable snake_case ID unique across all record types; records reference each other by typed ID, never by file path | — (proposed: ADR-0002) | ❌ GAP |
| TR-data-002 | data-config-pipeline.md | Data & Config | Foundation | The storage format, or a check on top of it, detects a missing field, a fractional integer and an unknown property | — (proposed: ADR-0002) | ❌ GAP |
| TR-data-003 | data-config-pipeline.md | Data & Config | Foundation | The catalogue loads from an explicit manifest of data files, never a directory scan, and loads correctly from an Android export | — (proposed: ADR-0002) | ❌ GAP |
| TR-data-004 | data-config-pipeline.md | Data & Config | Foundation | Loading is once and all-or-nothing (Unloaded, Loading, Ready/Failed), started by the app root before the first gameplay scene, with no reload | — (proposed: ADR-0001) | ❌ GAP |
| TR-data-005 | data-config-pipeline.md | Data & Config | Foundation | The validator collects every error as {code, source, record_id, field} before failing, in tiers (manifest, finiteness, bounds, tags, references) | — (proposed: ADR-0002) | ❌ GAP |
| TR-data-006 | data-config-pipeline.md | Data & Config | Foundation | No fallbacks in any build; a load failure shows a catalogue-free fatal screen that never opens saves, and dev runs name each error | — (proposed: ADR-0001) | ❌ GAP |
| TR-data-007 | data-config-pipeline.md | Data & Config | Foundation | Definitions are read-only after load and mutable state lives on runtime instances holding def_id; a deep-snapshot test proves the catalogue is unchanged after a battle | — (proposed: ADR-0002) | ❌ GAP |
| TR-data-008 | data-config-pipeline.md | Data & Config | Foundation | Every modifiable value is read through one stat accessor (read_context, stat_key) at use time, never cached, so Stat & Modifier Resolution can replace its internals with no call-site change | — (proposed: ADR-0005) | ❌ GAP |
| TR-data-009 | data-config-pipeline.md | Data & Config | Foundation | A bad accessor call goes to an injected, test-replaceable failure handler that survives release builds (not assert) | — (proposed: ADR-0001) | ❌ GAP |
| TR-data-010 | data-config-pipeline.md | Data & Config | Foundation | Data owns the stat-key vocabulary and int/float type per key, and exposes non-fatal level_count(def_id) and is_tower(id) | — (proposed: ADR-0005) | ❌ GAP |
| TR-data-011 | data-config-pipeline.md | Data & Config | Foundation | No autoload or global: the app root holds the Ready catalogue across retries and the battle builder injects it | — (proposed: ADR-0001) | ❌ GAP |
| TR-data-012 | data-config-pipeline.md | Data & Config | Foundation | Logic tests build fixture catalogues in code with no file I/O; a separate integration suite validates the real data files | — (proposed: ADR-0007) | ❌ GAP |
| TR-data-013 | data-config-pipeline.md | Data & Config | Foundation | A CI content test opens each Stage scene_ref, applies layout and wave rules, and checks rationale fields and owning-GDD balance ranges | — (proposed: ADR-0002) | ❌ GAP |
| TR-data-014 | data-config-pipeline.md | Data & Config | Foundation | The data store emits no signals; each emitter declares its own and the composition root wires them | — (proposed: ADR-0006) | ❌ GAP |
| TR-data-015 | data-config-pipeline.md | Data & Config | Foundation | Load-time targets: Loading to Ready median at most 1000 ms on an Adreno 5xx-class device; edit-to-in-game at most 10 s | — (proposed: ADR-0002) | ❌ GAP |
| TR-input-001 | input-gesture-resolver.md | Input & Gesture | Foundation | The resolver is a pure, scene-free, clock-free object driven only by press, move, release, cancel_pointer and cancel | — (proposed: ADR-0008) | ❌ GAP |
| TR-input-002 | input-gesture-resolver.md | Input & Gesture | Foundation | One thin adapter node is the only engine-facing input code; it maps Godot touch and mouse events to the five calls in 540x960 field units | — (proposed: ADR-0003) | ❌ GAP |
| TR-input-003 | input-gesture-resolver.md | Input & Gesture | Foundation | Every forwarded press is followed by exactly one release or cancel for that index, even under a mouse_filter STOP Control; the canceled flag is honoured | — (proposed: ADR-0003) | ❌ GAP |
| TR-input-004 | input-gesture-resolver.md | Input & Gesture | Foundation | The adapter runs PROCESS_MODE_ALWAYS and calls cancel() on app pause, focus loss and viewport resize, forwarding one lifecycle signal to Game State | — (proposed: ADR-0003) | ❌ GAP |
| TR-input-005 | input-gesture-resolver.md | Input & Gesture | Foundation | Touch and mouse use one event family: emulation settings stop duplicate presses, the mouse pointer index never collides with touch index 0, non-left buttons are dropped | — (proposed: ADR-0003) | ❌ GAP |
| TR-input-006 | input-gesture-resolver.md | Input & Gesture | Foundation | The adapter rejects presses inside edge_reject_margin and platform safe-area insets via DisplayServer.get_display_safe_area(), converted to field units | — (proposed: ADR-0003) | ❌ GAP |
| TR-input-007 | input-gesture-resolver.md | Input & Gesture | Foundation | A registry of disc hit targets {id, centre, radius, accepts, priority, enabled, sink}; register, unregister, set_centre and set_enabled are legal in any state and apply at once | — (proposed: ADR-0008) | ❌ GAP |
| TR-input-008 | input-gesture-resolver.md | Input & Gesture | Foundation | A four-state machine (Idle, Pressed, Dragging, Dead) with one active pointer freezes TAP and DRAG winners at press and classifies by per-press slop | — (proposed: ADR-0008) | ❌ GAP |
| TR-input-009 | input-gesture-resolver.md | Input & Gesture | Foundation | Signal API pressed, tap, ground_tap, drag_started, drag_moved, drag_ended, drag_cancelled, idle; every exit to Idle emits idle() last | — (proposed: ADR-0008) | ❌ GAP |
| TR-input-010 | input-gesture-resolver.md | Input & Gesture | Foundation | State commits before emit; gesture calls made inside a handler queue FIFO and drain synchronously in the outermost call | — (proposed: ADR-0008) | ❌ GAP |
| TR-input-011 | input-gesture-resolver.md | Input & Gesture | Foundation | Slops come by injection through static validate() and a create() factory returning null on bad input; non-finite positions are dropped with push_error | — (proposed: ADR-0008) | ❌ GAP |
| TR-input-012 | input-gesture-resolver.md | Input & Gesture | Foundation | Game State builds the resolver and adapter per battle from the Input record and injects the one resolver into Hero, Tower and HUD wrappers | — (proposed: ADR-0001) | ❌ GAP |
| TR-input-013 | input-gesture-resolver.md | Input & Gesture | Presentation | Burst button, build arc and world targets are resolver discs, not Controls; HUD Controls consume their events before the adapter, so routing order is fixed | — (proposed: ADR-0003) | ❌ GAP |
| TR-input-014 | input-gesture-resolver.md | Input & Gesture | Foundation | Identical call lists give identical signal logs; tests use a recording fake, not assert_signal; bots call commands directly plus one resolver equivalence test | — (proposed: ADR-0007) | ❌ GAP |
| TR-input-015 | input-gesture-resolver.md | Input & Gesture | Feature | Dev builds carry a gesture-log harness recording device, insets, timing, travel, winners and classification, plus each tower_upgraded commit and chip_state() at each tower prompt, for the Pillar 4 phone test | — (proposed: ADR-0008) | ❌ GAP |
| TR-input-016 | input-gesture-resolver.md | Input & Gesture | Foundation | Minimum width 360 dp by runtime guard; stretch mode keeps field units equal to viewport units, no Camera2D, and a cancel() on resize | — (proposed: ADR-0003) | ❌ GAP |
| TR-state-001 | game-state-stage-flow.md | Game State & Flow | Foundation | A minimal main-scene app root with no autoload triggers the catalogue load, holds the Ready catalogue, owns the fatal screen, and alone survives a retry | — (proposed: ADR-0001) | ❌ GAP |
| TR-state-002 | game-state-stage-flow.md | Game State & Flow | Foundation | A scene-free builder build(catalogue, stage_id, seed, fatal_handler) wires every battle system by explicit signal connections and runs headless; a thin wrapper adds tick loop, adapter and views | — (proposed: ADR-0001) | ❌ GAP |
| TR-state-003 | game-state-stage-flow.md | Game State & Flow | Foundation | Simulation time enters only through battle.tick(dt) at a fixed rate; no _process, Timers, await, wall clock or physics areas in gameplay; the wrapper clamps owed ticks | — (proposed: ADR-0004) | ❌ GAP |
| TR-state-004 | game-state-stage-flow.md | Game State & Flow | Foundation | Systems tick in one fixed documented order and player and bot commands apply only between ticks | — (proposed: ADR-0004) | ❌ GAP |
| TR-state-005 | game-state-stage-flow.md | Game State & Flow | Foundation | All randomness comes from an injected seed so stage, seed and command script give an identical result | — (proposed: ADR-0004) | ❌ GAP |
| TR-state-006 | game-state-stage-flow.md | Game State & Flow | Core | Flow and lives are a pure stage state machine (Build, Wave, Intermission, Paused, Won, Lost) with a result readable after the outcome | — (proposed: ADR-0004) | ❌ GAP |
| TR-state-007 | game-state-stage-flow.md | Game State & Flow | Core | Committing an outcome sets state, stops the clock, calls input.cancel(), then emits phase; remaining systems skip the rest of that tick | — (proposed: ADR-0004) | ❌ GAP |
| TR-state-008 | game-state-stage-flow.md | Game State & Flow | Core | Flow listens to synchronous wave_cleared, waves_complete and enemy_leaked (leak before complete) and emits lives_changed, phase and wave_called_early | — (proposed: ADR-0006) | ❌ GAP |
| TR-state-009 | game-state-stage-flow.md | Game State & Flow | Foundation | Retry destroys the whole battle and builds a new one between ticks, driven by a latch on the app root; a weakref to the old battle must be null | — (proposed: ADR-0001) | ❌ GAP |
| TR-state-010 | game-state-stage-flow.md | Game State & Flow | Foundation | Focus loss or backgrounding enters Paused: ticks stop, input cancels, the accumulator is zeroed, and a resume tap reaches nothing beneath | — (proposed: ADR-0003) | ❌ GAP |
| TR-state-011 | game-state-stage-flow.md | Game State & Flow | Foundation | One idempotent fatal handler keeps the first cause, latches, halts the tick and discards a partial build; the fatal screen is guaranteed to load | — (proposed: ADR-0001) | ❌ GAP |
| TR-state-012 | game-state-stage-flow.md | Game State & Flow | Core | Authored durations become whole ticks through one to_ticks conversion; countdowns are integer tick counters | — (proposed: ADR-0004) | ❌ GAP |
| TR-state-013 | game-state-stage-flow.md | Game State & Flow | Foundation | Tests can enumerate a battle's systems, inject recording fakes, snapshot a battle, and fail when any battle signal has no listener (views on an allowlist) | — (proposed: ADR-0007) | ❌ GAP |
| TR-state-014 | game-state-stage-flow.md | Game State & Flow | Presentation | Wrapper-side presentation timers (Lost delay, Won beat, button arming) run on the frame clock outside the simulation | — (proposed: ADR-0004) | ❌ GAP |
| TR-combat-001 | combat-damage.md | Combat & Damage | Core | Combat is three pieces: a DamageEvent value (target, amount, source_kind, source_id), one Health and one Status per enemy; no ProjectileSpawner | — (proposed: ADR-0009) | ❌ GAP |
| TR-combat-002 | combat-damage.md | Combat & Damage | Core | The enemy object exposes spawn_id, cached distance and position, and removed, and stays a valid reference after removal, so it cannot be a freed Node | — (proposed: ADR-0009) | ❌ GAP |
| TR-combat-003 | combat-damage.md | Combat & Damage | Core | Every HP change goes through deliver(event) inside a tick, applying min(amount, hp) after guards in fixed order with named push_error codes | — (proposed: ADR-0009) | ❌ GAP |
| TR-combat-004 | combat-damage.md | Combat & Damage | Core | Death is immediate at HP 0 or below; dead enemies cannot be targeted; the reap step removes the corpse and emits enemy_killed(bounty) once | — (proposed: ADR-0009) | ❌ GAP |
| TR-combat-005 | combat-damage.md | Combat & Damage | Core | Per-source damage counters expose dealt_by_id, dealt_by_kind, dealt_total and hero_share, readable until the battle is destroyed | — (proposed: ADR-0009) | ❌ GAP |
| TR-combat-006 | combat-damage.md | Combat & Damage | Core | Slow is per-instance whole-tick countdown state with replace/equal/ignore rules; movement multiplies move_speed by speed_factor(enemy) | — (proposed: ADR-0009) | ❌ GAP |
| TR-combat-007 | combat-damage.md | Combat & Damage | Core | Combat reads no catalogue data; callers pass values in and its only dependency is the pure to_ticks with dt injected | — (proposed: ADR-0009) | ❌ GAP |
| TR-combat-008 | combat-damage.md | Combat & Damage | Core | Pure targeting helpers first_in, nearest_in and all_in_radius use an inclusive squared-distance test, tie-break by lowest spawn_id and never mutate input | — (proposed: ADR-0009) | ❌ GAP |
| TR-combat-009 | combat-damage.md | Combat & Damage | Foundation | Tick order is Flow, Enemy & Wave advance, tick_status, Towers by slot, Hero then burst, reap; leaks resolve before fire | — (proposed: ADR-0004) | ❌ GAP |
| TR-combat-010 | combat-damage.md | Combat & Damage | Core | View-only attack_fired and damage_applied emit after commit with copied positions; listeners never call deliver, and results match with or without listeners | — (proposed: ADR-0006) | ❌ GAP |
| TR-combat-011 | combat-damage.md | Combat & Damage | Presentation | The Combat view draws primitives from one _draw() per kind with no shaders or particles and a 16-marker flash pool on the frame clock | — (proposed: ADR-0011) | ❌ GAP |
| TR-combat-012 | combat-damage.md | Combat & Damage | Foundation | Errors use push_error, asserted with gdUnit4 assert_error().is_push_error() and the push_error report setting on; invariant I checks damage sums | — (proposed: ADR-0007) | ❌ GAP |
| TR-combat-013 | combat-damage.md | Combat & Damage | Core | Per-tick targeting stays within budget on a low-end phone at the catch-up clamp (about 400 range checks, under 2 ms, unmeasured) | — (proposed: ADR-0009) | ❌ GAP |
| TR-combat-014 | combat-damage.md | Combat & Damage | Foundation | Determinism holds per CPU architecture only; bot baselines are kept per architecture | — (proposed: ADR-0004) | ❌ GAP |
| TR-enemy-001 | enemy-wave.md | Enemy & Wave | Foundation | The Stage record holds gameplay geometry (path_points, slot_positions, path_width, requires_bend, early_call_seconds_per_gold); the scene holds only the look | — (proposed: ADR-0002) | ❌ GAP |
| TR-enemy-002 | enemy-wave.md | Enemy & Wave | Foundation | Fixed tick dt with one to_ticks (round half away from zero); spawn ticks come from an absolute schedule, never a float countdown | — (proposed: ADR-0004) | ❌ GAP |
| TR-enemy-003 | enemy-wave.md | Enemy & Wave | Core | Enemy & Wave has two tick entries, advance (spawn, move, leak) and reap, in Combat's tick order; the battle passes the roster to tick_status | — (proposed: ADR-0004) | ❌ GAP |
| TR-enemy-004 | enemy-wave.md | Enemy & Wave | Core | enemy_leaked, enemy_killed, wave_cleared and waves_complete fire synchronously (no CONNECT_DEFERRED) in spawn_id order after commit; leaks come before the clear | — (proposed: ADR-0006) | ❌ GAP |
| TR-enemy-005 | enemy-wave.md | Enemy & Wave | Core | The builder injects a halted() callable checked after every accessor read and signal; the system never references Flow | — (proposed: ADR-0001) | ❌ GAP |
| TR-enemy-006 | enemy-wave.md | Enemy & Wave | Foundation | Every enemy stat is read through the accessor at use time with a reused per-enemy read context; Wave and Stage records are read directly and never written | — (proposed: ADR-0005) | ❌ GAP |
| TR-enemy-007 | enemy-wave.md | Enemy & Wave | Foundation | Waves use no randomness and never read the sim seed; cosmetic jitter uses a separate RNG; retry rebuilds identical spawn_id and schedule | — (proposed: ADR-0004) | ❌ GAP |
| TR-enemy-008 | enemy-wave.md | Enemy & Wave | Core | The roster solely owns its enemies, exposes read-only roster() and targets() in spawn_id order, and enemies keep no back-references so retry frees them | — (proposed: ADR-0009) | ❌ GAP |
| TR-enemy-009 | enemy-wave.md | Enemy & Wave | Core | How Health and Status attach to an enemy (spawn_id, def_id, distance, position, removed) is decided by ADR | — (proposed: ADR-0009) | ❌ GAP |
| TR-enemy-010 | enemy-wave.md | Enemy & Wave | Core | Position comes from distance along a polyline via a cached cumulative-length array, crossing several segments per step and clamped to the end | — (proposed: ADR-0009) | ❌ GAP |
| TR-enemy-011 | enemy-wave.md | Enemy & Wave | Core | An enemy is targetable only while its centre is inside the 540x960 field rectangle, a defined constant or injected value | — (proposed: ADR-0009) | ❌ GAP |
| TR-enemy-012 | enemy-wave.md | Enemy & Wave | Core | Wave control is a Waiting/Active/Finished machine with start_next_wave() logging to an injected dev-error sink, not assert | — (proposed: ADR-0001) | ❌ GAP |
| TR-enemy-013 | enemy-wave.md | Enemy & Wave | Core | One add-enemy step handles schedule spawns and future splitter children, joining atomically before the clear check | — (proposed: ADR-0009) | ❌ GAP |
| TR-enemy-014 | enemy-wave.md | Enemy & Wave | Foundation | A headless content test checks layout rules L1-L14 and wave rules on in-memory records; unit tests use fakes and no scene or files | — (proposed: ADR-0007) | ❌ GAP |
| TR-enemy-015 | enemy-wave.md | Enemy & Wave | Presentation | Views read roster() and the path each frame; fixed three-pass draw order; a view pool of at least 48 that grows with a dev error; Reduce Motion honoured | — (proposed: ADR-0011) | ❌ GAP |
| TR-enemy-016 | enemy-wave.md | Enemy & Wave | Core | Enemy & Wave exposes view-only wave_index() (1-based last wave started, 0 before the first start, set when start_next_wave commits, unchanged by a clear or an outcome) and got_through_by_type(), never reset per wave; the builder injects wave_index() into Flow's result | — (proposed: ADR-0009) | ❌ GAP |
| TR-tower-001 | tower-system.md | Tower | Core | TowerSim (builder-made, headless) holds gold, slots, towers and the tick; TowerInput (wrapper-made, absent headless) changes state only through upgrade | — (proposed: ADR-0010) | ❌ GAP |
| TR-tower-002 | tower-system.md | Tower | Core | build(slot_index, tower_id) and upgrade(slot_index) are the only mutation API, run between ticks and return a typed result enum in fixed check order | — (proposed: ADR-0010) | ❌ GAP |
| TR-tower-003 | tower-system.md | Tower | Foundation | Tower IDs and levels are validated with is_tower and level_count before any accessor read; cost and stats are read at use time | — (proposed: ADR-0005) | ❌ GAP |
| TR-tower-004 | tower-system.md | Tower | Core | Command commit is atomic: state commits before gold_changed then tower_built or tower_upgraded; a refusal changes and emits nothing | — (proposed: ADR-0006) | ❌ GAP |
| TR-tower-005 | tower-system.md | Tower | Core | Towers tick in ascending slot index; cooldown_left is an integer tick counter that runs on every tick, Intermission included | — (proposed: ADR-0004) | ❌ GAP |
| TR-tower-006 | tower-system.md | Tower | Core | The injected halted() is checked after every read and signal; all stats are read before any mutation so a bad read halts with nothing half done | — (proposed: ADR-0001) | ❌ GAP |
| TR-tower-007 | tower-system.md | Tower | Core | Targeting and damage go only through Combat's API; splash victims come only from targets() | — (proposed: ADR-0009) | ❌ GAP |
| TR-tower-008 | tower-system.md | Tower | Core | Gold is one non-negative integer owned by TowerSim, fed by starting_gold, enemy_killed(bounty) and wave_called_early; gold freezes once halted | — (proposed: ADR-0010) | ❌ GAP |
| TR-tower-009 | tower-system.md | Tower | Core | The early-call bonus is pure integer tick math, to_ticks(seconds_left) div to_ticks(rate) | — (proposed: ADR-0010) | ❌ GAP |
| TR-tower-010 | tower-system.md | Tower | Feature | The upgrade chip window runs on real time while the sim clock is stopped, via a pure ChipWindow.advance(ms) fed by the wrapper | — (proposed: ADR-0004) | ❌ GAP |
| TR-tower-011 | tower-system.md | Tower | Feature | TowerInput registers slots and the chip disc with the resolver, disables built slots, closes the chip on phase, and ignores taps while halted | — (proposed: ADR-0008) | ❌ GAP |
| TR-tower-012 | tower-system.md | Tower | Core | Signals have typed signatures (tower_id type undecided); gameplay may not depend on them and results match with or without listeners | — (proposed: ADR-0006) | ❌ GAP |
| TR-tower-013 | tower-system.md | Tower | Core | Retry teardown leaves no old battle alive through a signal connection; a listener-count wiring test names any missing connection | — (proposed: ADR-0001) | ❌ GAP |
| TR-tower-014 | tower-system.md | Tower | Foundation | All logic is unit-testable headless with spy accessor, recording fake and fake halted(); the content test enforces tower and gold rows | — (proposed: ADR-0007) | ❌ GAP |
| TR-tower-015 | tower-system.md | Tower | Presentation | All towers draw from one _draw() node with primitive polygons, level inset and a cooldown ring, with Reduce Motion fallbacks | — (proposed: ADR-0011) | ❌ GAP |
| TR-hero-001 | hero-system.md | Hero | Core | Hero splits into HeroSim (builder-made, headless) and HeroInput (wrapper-only), which changes battle state only through pin() and burst() | — (proposed: ADR-0010) | ❌ GAP |
| TR-hero-002 | hero-system.md | Hero | Core | pin() and burst() run between ticks and return ordered enum result codes, state checked before geometry; a refusal mutates nothing | — (proposed: ADR-0010) | ❌ GAP |
| TR-hero-003 | hero-system.md | Hero | Core | HeroSim ticks in the Hero-and-burst slot (walk, attack, cooldown, telegraph, release), uses to_ticks, and returns at once when halted() | — (proposed: ADR-0004) | ❌ GAP |
| TR-hero-004 | hero-system.md | Hero | Core | The builder injects halted(), in_build(), the hand flag, the Hero record ID and burst_id into HeroSim, HeroInput and the HUD | — (proposed: ADR-0001) | ❌ GAP |
| TR-hero-005 | hero-system.md | Hero | Foundation | Hero and Burst stats are read through the accessor at use time; hero_start, pin_rect and pin_exclusion come straight from the Stage record | — (proposed: ADR-0005) | ❌ GAP |
| TR-hero-006 | hero-system.md | Hero | Core | PinGeometry is a plain scene-free class computing in float scalars only (no Vector2 methods) with stated tolerances and tie-breaks | — (proposed: ADR-0004) | ❌ GAP |
| TR-hero-007 | hero-system.md | Hero | Core | Hero uses deliver with HERO/BURST source kinds, report_attack before deliver, and nearest_in, all_in_radius, is_dead, hp_left over targets() | — (proposed: ADR-0009) | ❌ GAP |
| TR-hero-008 | hero-system.md | Hero | Core | hero_pinned and burst_started emit after state is set and are on Flow's view allowlist; handlers never issue commands | — (proposed: ADR-0006) | ❌ GAP |
| TR-hero-009 | hero-system.md | Hero | Core | HeroSim exposes read-only queries and per-run counters (repins, bursts, victims, kills) for HUD, bots, logs and Stage Progression | — (proposed: ADR-0010) | ❌ GAP |
| TR-hero-010 | hero-system.md | Hero | Presentation | HeroInput registers hero DRAG, button DRAG and sink TAP discs, updates the walking hero's hit centre each frame, and hit-tests cancel hysteresis | — (proposed: ADR-0008) | ❌ GAP |
| TR-hero-011 | hero-system.md | Hero | Presentation | HeroInput's aim state machine and cooldown_digit() advance through an explicit update(), not engine frames | — (proposed: ADR-0004) | ❌ GAP |
| TR-hero-012 | hero-system.md | Hero | Core | A resolver-driven script and a direct-command script give tick-identical HeroSim state; a never-pinned run equals a HeroSim-absent run | — (proposed: ADR-0010) | ❌ GAP |
| TR-hero-013 | hero-system.md | Hero | Core | Pause stops the sim clock so walk and telegraph resume exactly; aims get drag_cancelled; Build runs no ticks, Intermission does | — (proposed: ADR-0004) | ❌ GAP |
| TR-hero-014 | hero-system.md | Hero | Foundation | Content tests enforce hero and burst rules (leash, telegraph, intermission, reach, hero_start, pin_exclusion, one Hero record), each proven on a broken fixture | — (proposed: ADR-0002) | ❌ GAP |
| TR-hero-015 | hero-system.md | Hero | Presentation | burst_button_centre() is owned by the HUD, read once by HeroInput at registration, and injectable by tests | — (proposed: ADR-0010) | ❌ GAP |
| TR-hud-001 | battle-hud.md | Battle HUD | Presentation | The HUD is HudLogic (plain), HudTopBand (display-only Controls) and HudField (one _draw, targets as resolver discs), absent headless and rebuilt on retry | — (proposed: ADR-0011) | ❌ GAP |
| TR-hud-002 | battle-hud.md | Battle HUD | Presentation | Result and Paused screens are full-screen modal Controls that consume every event before the Input adapter sees it | — (proposed: ADR-0003) | ❌ GAP |
| TR-hud-003 | battle-hud.md | Battle HUD | Presentation | A Control fires only on a release whose press it saw while Armed, and clears that press on lifecycle or focus-loss signals | — (proposed: ADR-0003) | ❌ GAP |
| TR-hud-004 | battle-hud.md | Battle HUD | Presentation | The HUD holds presentation state only and no reset path; full sim state is identical with or without the HUD | — (proposed: ADR-0006) | ❌ GAP |
| TR-hud-005 | battle-hud.md | Battle HUD | Core | Each frame runs input commands, then real-time models, then ticks, then views, so the displayed bonus equals the paid bonus | — (proposed: ADR-0004) | ❌ GAP |
| TR-hud-006 | battle-hud.md | Battle HUD | Foundation | Retry sets an idempotent latch on the app root and never frees its caller; the root's next frame checks Fatal, stops, cancels, frees and rebuilds | — (proposed: ADR-0001) | ❌ GAP |
| TR-hud-007 | battle-hud.md | Battle HUD | Presentation | Armed buttons go Hidden, Arming, Armed on a real-time advance(ms) clock clamped to 100 ms and frozen while Paused | — (proposed: ADR-0004) | ❌ GAP |
| TR-hud-008 | battle-hud.md | Battle HUD | Presentation | The build arc registers and unregisters resolver targets on open and close, disables Start/Call while open, and closes on outcome, Paused or Fatal | — (proposed: ADR-0008) | ❌ GAP |
| TR-hud-009 | battle-hud.md | Battle HUD | Presentation | The resolver's pressed payload exposes both best_tap and best_drag so the HUD can ignore a Start/Call tap that also hits the hero | — (proposed: ADR-0008) | ❌ GAP |
| TR-hud-010 | battle-hud.md | Battle HUD | Presentation | The HUD reads Flow, Tower, Hero, Enemy & Wave and Combat via signals and new view-only queries; phase and lives_changed join the view allowlist | — (proposed: ADR-0006) | ❌ GAP |
| TR-hud-011 | battle-hud.md | Battle HUD | Presentation | Costs are read through the accessor on arc open and gold_changed, and the burst wedge reads Burst cooldown through the accessor at use time with the builder-injected Burst ID; a read that finds halted() is abandoned for the Fatal screen | — (proposed: ADR-0005) | ❌ GAP |
| TR-hud-012 | battle-hud.md | Battle HUD | Presentation | The result screen and log come from one snapshot built the frame after the outcome | — (proposed: ADR-0006) | ❌ GAP |
| TR-hud-013 | battle-hud.md | Battle HUD | Foundation | Debug builds append JSON lines to user://run_log.jsonl through an injectable sink; a write failure is non-fatal and release builds never write | — (proposed: ADR-0010) | ❌ GAP |
| TR-hud-014 | battle-hud.md | Battle HUD | Presentation | Layout is in 540x960 field units with safe-area insets converted to field units; burst_y = clamp(888 - I_bottom, 816, 888) | — (proposed: ADR-0003) | ❌ GAP |
| TR-hud-015 | battle-hud.md | Battle HUD | Presentation | HUD budget about 8 (max 12) of 60 draw calls and at most 3 text draws; hit targets at least 72 units (48 dp), text at least 21 units | — (proposed: ADR-0011) | ❌ GAP |
| TR-hud-016 | battle-hud.md | Battle HUD | Foundation | Content tests enforce HUD layout rules (slot bounds, clearances, at most 3 next-wave types, 6 waves, 10 lives) | — (proposed: ADR-0002) | ❌ GAP |

## Known Gaps

Every requirement, grouped by the proposed ADR that would close it.

### ADR-0001 App Lifecycle, Composition Root and Fatal Path (15)
Suggested: `/architecture-decision App Lifecycle, Composition Root and Fatal Path`

TR-data-004, TR-data-006, TR-data-009, TR-data-011, TR-input-012, TR-state-001, TR-state-002, TR-state-009, TR-state-011, TR-enemy-005, TR-enemy-012, TR-tower-006, TR-tower-013, TR-hero-004, TR-hud-006

### ADR-0002 Catalogue Storage Format, Manifest and Validation (10)
Suggested: `/architecture-decision Catalogue Storage Format, Manifest and Validation`

TR-data-001, TR-data-002, TR-data-003, TR-data-005, TR-data-007, TR-data-013, TR-data-015, TR-enemy-001, TR-hero-014, TR-hud-016

### ADR-0003 Input Adapter, Display Stretch and Platform Lifecycle (11)
Suggested: `/architecture-decision Input Adapter, Display Stretch and Platform Lifecycle`

TR-input-002, TR-input-003, TR-input-004, TR-input-005, TR-input-006, TR-input-013, TR-input-016, TR-state-010, TR-hud-002, TR-hud-003, TR-hud-014

### ADR-0004 Fixed-Tick Clock, Tick Order, Frame Order and Determinism (20)
Suggested: `/architecture-decision Fixed-Tick Clock, Tick Order, Frame Order and Determinism`

TR-state-003, TR-state-004, TR-state-005, TR-state-006, TR-state-007, TR-state-012, TR-state-014, TR-combat-009, TR-combat-014, TR-enemy-002, TR-enemy-003, TR-enemy-007, TR-tower-005, TR-tower-010, TR-hero-003, TR-hero-006, TR-hero-011, TR-hero-013, TR-hud-005, TR-hud-007

### ADR-0005 Stat Accessor and Read-Context Contract (6)
Suggested: `/architecture-decision Stat Accessor and Read-Context Contract`

TR-data-008, TR-data-010, TR-enemy-006, TR-tower-003, TR-hero-005, TR-hud-011

### ADR-0006 Battle Signal Contracts and View Allowlist (10)
Suggested: `/architecture-decision Battle Signal Contracts and View Allowlist`

TR-data-014, TR-state-008, TR-combat-010, TR-enemy-004, TR-tower-004, TR-tower-012, TR-hero-008, TR-hud-004, TR-hud-010, TR-hud-012

### ADR-0007 Headless Test Harness, gdUnit4 and Layer Lint (6)
Suggested: `/architecture-decision Headless Test Harness, gdUnit4 and Layer Lint`

TR-data-012, TR-input-014, TR-state-013, TR-combat-012, TR-enemy-014, TR-tower-014

### ADR-0008 Input Resolver Core and Signal Contract (11)
Suggested: `/architecture-decision Input Resolver Core and Signal Contract`

TR-input-001, TR-input-007, TR-input-008, TR-input-009, TR-input-010, TR-input-011, TR-input-015, TR-tower-011, TR-hero-010, TR-hud-008, TR-hud-009

### ADR-0009 Enemy Entity, Roster and Combat API (17)
Suggested: `/architecture-decision Enemy Entity, Roster and Combat API`

TR-combat-001, TR-combat-002, TR-combat-003, TR-combat-004, TR-combat-005, TR-combat-006, TR-combat-007, TR-combat-008, TR-combat-013, TR-enemy-008, TR-enemy-009, TR-enemy-010, TR-enemy-011, TR-enemy-013, TR-enemy-016, TR-tower-007, TR-hero-007

### ADR-0010 Sim/Input Split, Command Result Codes and Dev Telemetry (10)
Suggested: `/architecture-decision Sim/Input Split, Command Result Codes and Dev Telemetry`

TR-tower-001, TR-tower-002, TR-tower-008, TR-tower-009, TR-hero-001, TR-hero-002, TR-hero-009, TR-hero-012, TR-hero-015, TR-hud-013

### ADR-0011 Battle Field Rendering and Draw-Call Budget (5)
Suggested: `/architecture-decision Battle Field Rendering and Draw-Call Budget`

TR-combat-011, TR-enemy-015, TR-tower-015, TR-hud-001, TR-hud-015

## Superseded Requirements
None. No ADR has been written, so no GDD has changed after an ADR.

## Changes since the first review
- New: TR-enemy-016 (`wave_index()` definition, cross-GDD review scenario 4).
- Revised: TR-input-015 (gesture log also records `tower_upgraded` and `chip_state()`, cross-GDD B3).
- Revised: TR-hud-011 (burst wedge reads Burst `cooldown` through the accessor, cross-GDD B2).
