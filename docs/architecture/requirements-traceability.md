# Architecture Traceability Index
Last Updated: 2026-11-05 (fourth review, `architecture-review-2026-11-05.md`)
Engine: Godot 4.7.2 (GDScript, Mobile renderer)

## Coverage Summary
- Total requirements: 124 (123 from the last review, plus TR-state-015)
- Covered: 119 (96%), all by Accepted ADRs; 9 of them are split across two Accepted ADRs
- Covered (Proposed): 0
- Partial: 5 (TR-data-003, TR-data-015, TR-input-006, TR-combat-013, TR-hud-015)
- Gaps: 0

By layer tag: Foundation 55 (52 covered, 3 partial), Core 46 (45 covered, 1 partial), Feature 3 (3 covered), Presentation 20 (19 covered, 1 partial).

Coverage counts only Accepted ADRs. All eleven ADRs (ADR-0001 to ADR-0011) are Accepted.
The ADR column names the ADR that covers each row; a split row names both, primary first.
Each Partial row names who owns the rest. Every rest is a device or GPU proof, or a GDD
that does not exist yet; none waits on an unwritten ADR.

## Full Matrix
| Requirement ID | GDD | System | Layer | Requirement | ADR Coverage | Status |
|---|---|---|---|---|---|---|
| TR-data-001 | data-config-pipeline.md | Data & Config | Foundation | Typed read-only records keyed by a stable snake_case ID unique across all record types; records reference each other by typed ID, never by file path | ADR-0002 | ✅ Covered |
| TR-data-002 | data-config-pipeline.md | Data & Config | Foundation | The storage format, or a check on top of it, detects a missing field, a fractional integer and an unknown property | ADR-0002 | ✅ Covered |
| TR-data-003 | data-config-pipeline.md | Data & Config | Foundation | The catalogue loads from an explicit manifest of data files, never a directory scan, and loads correctly from an Android export | ADR-0002; rest: Android export proof X2 (device, Technical Setup) | ⚠️ Partial |
| TR-data-004 | data-config-pipeline.md | Data & Config | Foundation | Loading is once and all-or-nothing (Unloaded, Loading, Ready/Failed), started by the app root before the first gameplay scene, with no reload | ADR-0001 | ✅ Covered |
| TR-data-005 | data-config-pipeline.md | Data & Config | Foundation | The validator collects every error as {code, source, record_id, field} before failing, in tiers (manifest, finiteness, bounds, tags, references) | ADR-0002 | ✅ Covered |
| TR-data-006 | data-config-pipeline.md | Data & Config | Foundation | No fallbacks in any build; a load failure shows a catalogue-free fatal screen that never opens saves, and dev runs name each error | ADR-0001 | ✅ Covered |
| TR-data-007 | data-config-pipeline.md | Data & Config | Foundation | Definitions are read-only after load and mutable state lives on runtime instances holding def_id; a deep-snapshot test proves the catalogue is unchanged after a battle | ADR-0002 | ✅ Covered |
| TR-data-008 | data-config-pipeline.md | Data & Config | Foundation | Every modifiable value is read through one stat accessor (read_context, stat_key) at use time, never cached, so Stat & Modifier Resolution can replace its internals with no call-site change | ADR-0005 | ✅ Covered |
| TR-data-009 | data-config-pipeline.md | Data & Config | Foundation | A bad accessor call goes to an injected, test-replaceable failure handler that survives release builds (not assert) | ADR-0001 | ✅ Covered |
| TR-data-010 | data-config-pipeline.md | Data & Config | Foundation | Data owns the stat-key vocabulary and int/float type per key, and exposes non-fatal level_count(def_id) and is_tower(id) | ADR-0005 | ✅ Covered |
| TR-data-011 | data-config-pipeline.md | Data & Config | Foundation | No autoload or global: the app root holds the Ready catalogue across retries and the battle builder injects it | ADR-0001 | ✅ Covered |
| TR-data-012 | data-config-pipeline.md | Data & Config | Foundation | Logic tests build fixture catalogues in code with no file I/O; a separate integration suite validates the real data files | ADR-0007 | ✅ Covered |
| TR-data-013 | data-config-pipeline.md | Data & Config | Foundation | A CI content test opens each Stage scene_ref, applies layout and wave rules, checks rationale fields and owning-GDD balance ranges, and fails a data file the manifest omits, a manifest path whose case differs from the file, a key repeated inside one JSON object, and a path_points coordinate that a 32-bit float cannot hold exactly | ADR-0002 (float32 path point part: ADR-0009 Decision 4) | ✅ Covered |
| TR-data-014 | data-config-pipeline.md | Data & Config | Foundation | The data store emits no signals; each emitter declares its own and the composition root wires them | ADR-0006 | ✅ Covered |
| TR-data-015 | data-config-pipeline.md | Data & Config | Foundation | Load-time targets: Loading to Ready median at most 1000 ms on an Adreno 5xx-class device; edit-to-in-game at most 10 s | ADR-0002; rest: device timings P1, P2 (first phone build) | ⚠️ Partial |
| TR-data-016 | data-config-pipeline.md | Data & Config | Foundation | The load fails with record_count, at the type tier before record checks, unless the catalogue holds exactly one Input record and exactly one Hero record, since the builder selects neither | ADR-0002 | ✅ Covered |
| TR-input-001 | input-gesture-resolver.md | Input & Gesture | Foundation | The resolver is a pure, scene-free, clock-free object driven only by press, move, release, cancel_pointer and cancel | ADR-0008 | ✅ Covered |
| TR-input-002 | input-gesture-resolver.md | Input & Gesture | Foundation | One thin adapter node is the only engine-facing input code; it maps Godot touch and mouse events to the five calls in 540x960 field units | ADR-0003 | ✅ Covered |
| TR-input-003 | input-gesture-resolver.md | Input & Gesture | Foundation | Every forwarded press is followed by exactly one release or cancel for that index, even under a mouse_filter STOP Control; the canceled flag is honoured | ADR-0003 | ✅ Covered |
| TR-input-004 | input-gesture-resolver.md | Input & Gesture | Foundation | The adapter runs PROCESS_MODE_ALWAYS and calls cancel() on app pause, focus loss and viewport resize, forwarding one lifecycle signal to Game State | ADR-0003 | ✅ Covered |
| TR-input-005 | input-gesture-resolver.md | Input & Gesture | Foundation | Touch and mouse use one event family: emulation settings stop duplicate presses, the mouse pointer index never collides with touch index 0, non-left buttons are dropped | ADR-0003 | ✅ Covered |
| TR-input-006 | input-gesture-resolver.md | Input & Gesture | Foundation | The adapter rejects presses inside edge_reject_margin and platform safe-area insets via DisplayServer.get_display_safe_area(), converted to field units | ADR-0003; rest: gesture insets owed to the Mobile Platform GDD (QQ-21), which does not exist | ⚠️ Partial |
| TR-input-007 | input-gesture-resolver.md | Input & Gesture | Foundation | A registry of disc hit targets {id, centre, radius, accepts, priority, enabled, sink}; register, unregister, set_centre and set_enabled are legal in any state and apply at once | ADR-0008 | ✅ Covered |
| TR-input-008 | input-gesture-resolver.md | Input & Gesture | Foundation | A four-state machine (Idle, Pressed, Dragging, Dead) with one active pointer freezes TAP and DRAG winners at press and classifies by per-press slop | ADR-0008 | ✅ Covered |
| TR-input-009 | input-gesture-resolver.md | Input & Gesture | Foundation | Signal API pressed, tapped, ground_tapped, drag_started, drag_moved, drag_ended, drag_cancelled, became_idle; every exit to Idle emits became_idle() last | ADR-0008 | ✅ Covered |
| TR-input-010 | input-gesture-resolver.md | Input & Gesture | Foundation | State commits before emit; gesture calls made inside a handler queue FIFO and drain synchronously in the outermost call | ADR-0008 | ✅ Covered |
| TR-input-011 | input-gesture-resolver.md | Input & Gesture | Foundation | Slops come by injection through static validate() and a create() factory returning null on bad input; non-finite positions are dropped with push_error | ADR-0008 | ✅ Covered |
| TR-input-012 | input-gesture-resolver.md | Input & Gesture | Foundation | Game State builds the resolver and adapter per battle from the Input record and injects the one resolver into Hero, Tower and HUD wrappers | ADR-0001 | ✅ Covered |
| TR-input-013 | input-gesture-resolver.md | Input & Gesture | Presentation | Burst button, build arc and world targets are resolver discs, not Controls; HUD Controls consume their events before the adapter, so routing order is fixed | ADR-0003 + ADR-0008 | ✅ Covered (split) |
| TR-input-014 | input-gesture-resolver.md | Input & Gesture | Foundation | Identical call lists give identical signal logs; tests use a recording fake, not assert_signal; bots call commands directly plus one resolver equivalence test | ADR-0007 + ADR-0010 (bots, equivalence test) | ✅ Covered (split) |
| TR-input-015 | input-gesture-resolver.md | Input & Gesture | Feature | Dev builds carry a gesture-log harness recording device, insets, timing, travel, winners and classification, plus each tower_upgraded commit and chip_state() at each tower prompt, for the Pillar 4 phone test | ADR-0008 + ADR-0010 (JsonlFileSink) | ✅ Covered (split) |
| TR-input-016 | input-gesture-resolver.md | Input & Gesture | Foundation | Minimum 360 x 640 dp effective scale by runtime guard; stretch mode keeps field units equal to viewport units, no Camera2D, and a cancel() on resize | ADR-0003 | ✅ Covered |
| TR-input-017 | input-gesture-resolver.md | Input & Gesture | Foundation | cancel() has three callers: the adapter (away, back request, resize), Flow through an injected cancel_input() on Won, Lost, Paused and Fatal, and the app root at teardown; a stale release after a non-adapter cancel reaches the resolver in Idle and is dropped | ADR-0001 (Decision 7, QQ-20) + ADR-0003 | ✅ Covered (split) |
| TR-state-001 | game-state-stage-flow.md | Game State & Flow | Foundation | A minimal main-scene app root with no autoload triggers the catalogue load, holds the Ready catalogue, owns the fatal screen, and alone survives a retry | ADR-0001 | ✅ Covered |
| TR-state-002 | game-state-stage-flow.md | Game State & Flow | Foundation | A scene-free builder build(catalogue, stage_id, seed, fatal_handler) wires every battle system by explicit signal connections and runs headless; a thin wrapper adds tick loop, adapter and views | ADR-0001 | ✅ Covered |
| TR-state-003 | game-state-stage-flow.md | Game State & Flow | Foundation | Simulation time enters only through battle.tick(dt) at a fixed rate; no _process, Timers, await, wall clock or physics areas in gameplay; the wrapper clamps owed ticks | ADR-0004 | ✅ Covered |
| TR-state-004 | game-state-stage-flow.md | Game State & Flow | Foundation | Systems tick in one fixed documented order and player and bot commands apply only between ticks | ADR-0004 | ✅ Covered |
| TR-state-005 | game-state-stage-flow.md | Game State & Flow | Foundation | All randomness comes from an injected seed so stage, seed and command script give an identical result | ADR-0004 | ✅ Covered |
| TR-state-006 | game-state-stage-flow.md | Game State & Flow | Core | Flow and lives are a pure stage state machine (Build, Wave, Intermission, Paused, Won, Lost) with a result readable after the outcome | ADR-0004 + ADR-0006 | ✅ Covered (split) |
| TR-state-007 | game-state-stage-flow.md | Game State & Flow | Core | Committing an outcome sets state, stops the clock, calls input.cancel(), then emits phase; remaining systems skip the rest of that tick | ADR-0004 | ✅ Covered |
| TR-state-008 | game-state-stage-flow.md | Game State & Flow | Core | Flow listens to synchronous wave_cleared, waves_completed and enemy_leaked (leak before completed) and emits lives_changed, phase_changed and wave_called_early | ADR-0006 | ✅ Covered |
| TR-state-009 | game-state-stage-flow.md | Game State & Flow | Foundation | Retry destroys the whole battle and builds a new one between ticks, driven by a latch on the app root; a weakref to the old battle must be null | ADR-0001 | ✅ Covered |
| TR-state-010 | game-state-stage-flow.md | Game State & Flow | Foundation | Focus loss or backgrounding enters Paused: ticks stop, input cancels, the accumulator is zeroed, and a resume tap reaches nothing beneath | ADR-0003 + ADR-0004 | ✅ Covered (split) |
| TR-state-011 | game-state-stage-flow.md | Game State & Flow | Foundation | One idempotent fatal handler keeps the first cause, latches, halts the tick and discards a partial build; the fatal screen is guaranteed to load | ADR-0001 | ✅ Covered |
| TR-state-012 | game-state-stage-flow.md | Game State & Flow | Core | Authored durations become whole ticks through one to_ticks conversion; countdowns are integer tick counters | ADR-0004 | ✅ Covered |
| TR-state-013 | game-state-stage-flow.md | Game State & Flow | Foundation | Tests can enumerate a battle's systems, inject recording fakes, snapshot a battle, and fail when any battle signal has no listener (views on an allowlist) | ADR-0007 | ✅ Covered |
| TR-state-014 | game-state-stage-flow.md | Game State & Flow | Presentation | Wrapper-side presentation timers (Lost delay, Won beat, button arming) run on the frame clock outside the simulation | ADR-0004 | ✅ Covered |
| TR-state-015 | game-state-stage-flow.md | Game State & Flow | Core | Flow's commands start_wave() and call_early() run between ticks and return their own result enums in fixed check order (OK, BUSY, HALTED, then the phase checks: NOT_BUILD; NOT_INTERMISSION, NO_TIME_LEFT); a refusal changes and emits nothing | ADR-0010 | ✅ Covered |
| TR-combat-001 | combat-damage.md | Combat & Damage | Core | Combat is three pieces: a DamageEvent value (target, amount, source_kind, source_id), one Health and one Status per enemy; no ProjectileSpawner | ADR-0009 | ✅ Covered |
| TR-combat-002 | combat-damage.md | Combat & Damage | Core | The enemy object exposes spawn_id, cached distance and position, and removed, and stays a valid reference after removal, so it cannot be a freed Node | ADR-0009 | ✅ Covered |
| TR-combat-003 | combat-damage.md | Combat & Damage | Core | Every HP change goes through deliver(event) inside a tick, applying min(amount, hp) after guards in fixed order with named push_error codes | ADR-0009 | ✅ Covered |
| TR-combat-004 | combat-damage.md | Combat & Damage | Core | Death is immediate at HP 0 or below; dead enemies cannot be targeted; the reap step removes the corpse and emits enemy_killed(bounty) once | ADR-0009 | ✅ Covered |
| TR-combat-005 | combat-damage.md | Combat & Damage | Core | Per-source damage counters expose dealt_by_id, dealt_by_kind, dealt_total and hero_share, readable until the battle is destroyed | ADR-0009 | ✅ Covered |
| TR-combat-006 | combat-damage.md | Combat & Damage | Core | Slow is per-instance whole-tick countdown state with replace/equal/ignore rules; movement multiplies move_speed by speed_factor(enemy) | ADR-0009 | ✅ Covered |
| TR-combat-007 | combat-damage.md | Combat & Damage | Core | Combat reads no catalogue data; callers pass values in and its only dependency is the pure to_ticks with dt injected | ADR-0009 | ✅ Covered |
| TR-combat-008 | combat-damage.md | Combat & Damage | Core | Pure targeting helpers first_in, nearest_in and all_in_radius use an inclusive squared-distance test, tie-break by lowest spawn_id and never mutate input | ADR-0009 | ✅ Covered |
| TR-combat-009 | combat-damage.md | Combat & Damage | Foundation | Tick order is Flow, Enemy & Wave advance, tick_status, Towers by slot, Hero then burst, reap; leaks resolve before fire | ADR-0004 | ✅ Covered |
| TR-combat-010 | combat-damage.md | Combat & Damage | Core | View-only attack_fired and damage_applied emit after commit with copied positions; listeners never call deliver, and results match with or without listeners | ADR-0006 + ADR-0009 (payload) | ✅ Covered (split) |
| TR-combat-011 | combat-damage.md | Combat & Damage | Presentation | The Combat view draws primitives from one _draw() per kind with no shaders or particles and a 16-marker flash pool on the frame clock | ADR-0011 | ✅ Covered |
| TR-combat-012 | combat-damage.md | Combat & Damage | Foundation | Errors use push_error, asserted with gdUnit4 assert_error().is_push_error() and the push_error report setting on; invariant I checks damage sums | ADR-0007 | ✅ Covered |
| TR-combat-013 | combat-damage.md | Combat & Damage | Core | Per-tick targeting stays within budget on a low-end phone at the catch-up clamp (about 400 range checks, under 2 ms, unmeasured) | ADR-0009 Decision 8; rest: P2 in a release export and ADR-0004 V13 on device | ⚠️ Partial |
| TR-combat-014 | combat-damage.md | Combat & Damage | Foundation | Determinism holds per CPU architecture only; bot baselines are kept per architecture | ADR-0004 | ✅ Covered |
| TR-enemy-001 | enemy-wave.md | Enemy & Wave | Foundation | The Stage record holds gameplay geometry (path_points, slot_positions, path_width, requires_bend, early_call_seconds_per_gold); the scene holds only the look | ADR-0002 | ✅ Covered |
| TR-enemy-002 | enemy-wave.md | Enemy & Wave | Foundation | Fixed tick dt with one to_ticks (round half away from zero); spawn ticks come from an absolute schedule, never a float countdown | ADR-0004 | ✅ Covered |
| TR-enemy-003 | enemy-wave.md | Enemy & Wave | Core | Enemy & Wave has two tick entries, advance (spawn, move, leak) and reap, in Combat's tick order; the battle passes the roster to tick_status | ADR-0004 | ✅ Covered |
| TR-enemy-004 | enemy-wave.md | Enemy & Wave | Core | enemy_leaked, enemy_killed, wave_cleared and waves_completed fire synchronously (no CONNECT_DEFERRED) in spawn_id order after commit; leaks come before the clear | ADR-0006 | ✅ Covered |
| TR-enemy-005 | enemy-wave.md | Enemy & Wave | Core | The builder injects a halted() callable checked after every accessor read and signal; the system never references Flow | ADR-0001 | ✅ Covered |
| TR-enemy-006 | enemy-wave.md | Enemy & Wave | Foundation | Every enemy stat is read through the accessor at use time with a reused per-enemy read context; Wave and Stage records are read directly and never written | ADR-0005 | ✅ Covered |
| TR-enemy-007 | enemy-wave.md | Enemy & Wave | Foundation | Waves use no randomness and never read the sim seed; cosmetic jitter uses a separate RNG; retry rebuilds identical spawn_id and schedule | ADR-0004 | ✅ Covered |
| TR-enemy-008 | enemy-wave.md | Enemy & Wave | Core | The roster solely owns its enemies, exposes read-only roster() and targets() in spawn_id order, and enemies keep no back-references so retry frees them | ADR-0009 | ✅ Covered |
| TR-enemy-009 | enemy-wave.md | Enemy & Wave | Core | How Health and Status attach to an enemy (spawn_id, def_id, distance, position, removed) is decided by ADR | ADR-0009 | ✅ Covered |
| TR-enemy-010 | enemy-wave.md | Enemy & Wave | Core | Position comes from distance along a polyline via a cached cumulative-length array, crossing several segments per step and clamped to the end | ADR-0009 | ✅ Covered |
| TR-enemy-011 | enemy-wave.md | Enemy & Wave | Core | An enemy is targetable only while its centre is inside the 540x960 field rectangle, a defined constant or injected value | ADR-0009 | ✅ Covered |
| TR-enemy-012 | enemy-wave.md | Enemy & Wave | Core | Wave control is a Waiting/Active/Finished machine with start_next_wave() logging to an injected dev-error sink, not assert | ADR-0001 | ✅ Covered |
| TR-enemy-013 | enemy-wave.md | Enemy & Wave | Core | One add-enemy step handles schedule spawns and future splitter children, joining atomically before the clear check | ADR-0009 | ✅ Covered |
| TR-enemy-014 | enemy-wave.md | Enemy & Wave | Foundation | A headless content test checks layout rules L1-L14 and wave rules on in-memory records; unit tests use fakes and no scene or files | ADR-0007 | ✅ Covered |
| TR-enemy-015 | enemy-wave.md | Enemy & Wave | Presentation | Views read roster() and the path each frame; fixed three-pass draw order; a view pool of at least 48 that grows with a dev error; Reduce Motion honoured | ADR-0011 | ✅ Covered |
| TR-enemy-016 | enemy-wave.md | Enemy & Wave | Core | Enemy & Wave exposes view-only wave_index() (1-based last wave started, 0 before the first start, set when start_next_wave commits, unchanged by a clear or an outcome) and got_through_by_type(), never reset per wave; the builder injects wave_index() into Flow's result | ADR-0009 | ✅ Covered |
| TR-tower-001 | tower-system.md | Tower | Core | TowerSim (builder-made, headless) holds gold, slots, towers and the tick; TowerInput (wrapper-made, absent headless) changes state only through upgrade | ADR-0010 | ✅ Covered |
| TR-tower-002 | tower-system.md | Tower | Core | build(slot_index, tower_id) and upgrade(slot_index) are the only mutation API, run between ticks and return a typed result enum in fixed check order | ADR-0010 | ✅ Covered |
| TR-tower-003 | tower-system.md | Tower | Foundation | Tower IDs and levels are validated with is_tower and level_count before any accessor read; cost and stats are read at use time | ADR-0005 | ✅ Covered |
| TR-tower-004 | tower-system.md | Tower | Core | Command commit is atomic: state commits before gold_changed then tower_built or tower_upgraded; a refusal changes and emits nothing | ADR-0006 | ✅ Covered |
| TR-tower-005 | tower-system.md | Tower | Core | Towers tick in ascending slot index; cooldown_left is an integer tick counter that runs on every tick, Intermission included | ADR-0004 | ✅ Covered |
| TR-tower-006 | tower-system.md | Tower | Core | The injected halted() is checked after every read and signal; all stats are read before any mutation so a bad read halts with nothing half done | ADR-0001 (halted) + ADR-0010 (read before mutate) | ✅ Covered (split) |
| TR-tower-007 | tower-system.md | Tower | Core | Targeting and damage go only through Combat's API; splash victims come only from targets() | ADR-0009 | ✅ Covered |
| TR-tower-008 | tower-system.md | Tower | Core | Gold is one non-negative integer owned by TowerSim, fed by starting_gold, enemy_killed(bounty) and wave_called_early; gold freezes once halted | ADR-0010 | ✅ Covered |
| TR-tower-009 | tower-system.md | Tower | Core | The early-call bonus is pure integer tick math, to_ticks(seconds_left) div to_ticks(rate) | ADR-0010 | ✅ Covered |
| TR-tower-010 | tower-system.md | Tower | Feature | The upgrade chip window runs on real time while the sim clock is stopped, via a pure ChipWindow.advance(ms) fed by the wrapper | ADR-0004 | ✅ Covered |
| TR-tower-011 | tower-system.md | Tower | Feature | TowerInput registers slots and the chip disc with the resolver, disables built slots, closes the chip on phase, and ignores taps while halted | ADR-0008 | ✅ Covered |
| TR-tower-012 | tower-system.md | Tower | Core | Signals have typed signatures (tower_id is a StringName); gameplay may not depend on them and results match with or without listeners | ADR-0006 | ✅ Covered |
| TR-tower-013 | tower-system.md | Tower | Core | Retry teardown leaves no old battle alive through a signal connection; a listener-count wiring test names any missing connection | ADR-0001 | ✅ Covered |
| TR-tower-014 | tower-system.md | Tower | Foundation | All logic is unit-testable headless with spy accessor, recording fake and fake halted(); the content test enforces tower and gold rows | ADR-0007 | ✅ Covered |
| TR-tower-015 | tower-system.md | Tower | Presentation | All towers draw from one _draw() node with primitive polygons, level inset and a cooldown ring, with Reduce Motion fallbacks | ADR-0011 | ✅ Covered |
| TR-hero-001 | hero-system.md | Hero | Core | Hero splits into HeroSim (builder-made, headless) and HeroInput (wrapper-only), which changes battle state only through pin() and burst() | ADR-0010 | ✅ Covered |
| TR-hero-002 | hero-system.md | Hero | Core | pin() and burst() run between ticks and return ordered enum result codes (BUSY first, then HALTED), state checked before geometry; every stat read comes before the commit and a read that latches Fatal returns HALTED; a refusal mutates nothing | ADR-0010 | ✅ Covered |
| TR-hero-003 | hero-system.md | Hero | Core | HeroSim ticks in the Hero-and-burst slot (walk, attack, cooldown, telegraph, release), uses to_ticks, and returns at once when halted() | ADR-0004 | ✅ Covered |
| TR-hero-004 | hero-system.md | Hero | Core | The builder injects halted(), in_build(), the hand flag, the Hero record ID and burst_id into HeroSim, HeroInput and the HUD | ADR-0001 | ✅ Covered |
| TR-hero-005 | hero-system.md | Hero | Foundation | Hero and Burst stats are read through the accessor at use time; hero_start, pin_rect and pin_exclusion come straight from the Stage record | ADR-0005 | ✅ Covered |
| TR-hero-006 | hero-system.md | Hero | Core | PinGeometry is a plain scene-free class computing in float scalars only (no Vector2 methods) with stated tolerances and tie-breaks | ADR-0004 | ✅ Covered |
| TR-hero-007 | hero-system.md | Hero | Core | Hero uses deliver with HERO/BURST source kinds, report_attack before deliver, and nearest_in, all_in_radius, is_dead, hp_left over targets() | ADR-0009 | ✅ Covered |
| TR-hero-008 | hero-system.md | Hero | Core | hero_pinned and burst_started emit after state is set and are on Flow's view allowlist; handlers never issue commands | ADR-0006 | ✅ Covered |
| TR-hero-009 | hero-system.md | Hero | Core | HeroSim exposes read-only queries and per-run counters (repins, bursts, victims, kills) for HUD, bots, logs and Stage Progression | ADR-0010 | ✅ Covered |
| TR-hero-010 | hero-system.md | Hero | Presentation | HeroInput registers hero DRAG, button DRAG and sink TAP discs, updates the walking hero's hit centre each frame, and hit-tests cancel hysteresis | ADR-0008 | ✅ Covered |
| TR-hero-011 | hero-system.md | Hero | Presentation | HeroInput's aim state machine and cooldown_digit() advance through an explicit update(), not engine frames | ADR-0004 | ✅ Covered |
| TR-hero-012 | hero-system.md | Hero | Core | A resolver-driven script and a direct-command script give tick-identical HeroSim state; a never-pinned HeroSim makes no stat read, no Combat call of kind HERO or BURST, no emit and no field change on any tick, and Battle.tick reaches Hero only through hero_sim.tick() | ADR-0010 | ✅ Covered |
| TR-hero-013 | hero-system.md | Hero | Core | Pause stops the sim clock so walk and telegraph resume exactly; aims get drag_cancelled; Build runs no ticks, Intermission does | ADR-0004 | ✅ Covered |
| TR-hero-014 | hero-system.md | Hero | Foundation | Content tests enforce hero and burst rules (leash, telegraph, intermission, reach, hero_start, pin_exclusion), each proven on a broken fixture; the one-Hero-record rule moved to the boot check (TR-data-016) | ADR-0002 | ✅ Covered |
| TR-hero-015 | hero-system.md | Hero | Presentation | burst_button_centre() is owned by the HUD, read once by HeroInput at registration, and injectable by tests | ADR-0010 | ✅ Covered |
| TR-hud-001 | battle-hud.md | Battle HUD | Presentation | The HUD is four pieces, absent headless and rebuilt on retry: HudLogic (plain), HudTopBand (one display-only Control that draws no text and sets accessibility_name and accessibility_live for gold and lives), HudField (one _draw above the field, all HUD text in one last pass by size, targets as resolver discs) and RangeRingView (a second _draw node under the field entities) | ADR-0011 | ✅ Covered |
| TR-hud-002 | battle-hud.md | Battle HUD | Presentation | Result and Paused screens are full-screen modal Controls that consume every press before the Input adapter sees it | ADR-0003 | ✅ Covered |
| TR-hud-003 | battle-hud.md | Battle HUD | Presentation | A Control fires only on a release whose press it saw while Armed, and clears that press on lifecycle or focus-loss signals | ADR-0003 | ✅ Covered |
| TR-hud-004 | battle-hud.md | Battle HUD | Presentation | The HUD holds presentation state only and no reset path; full sim state is identical with or without the HUD | ADR-0006 | ✅ Covered |
| TR-hud-005 | battle-hud.md | Battle HUD | Core | Each frame runs input commands, then real-time models, then ticks, then views, so the displayed bonus equals the paid bonus | ADR-0004 | ✅ Covered |
| TR-hud-006 | battle-hud.md | Battle HUD | Foundation | Retry sets an idempotent latch on the app root and never frees its caller; the root's next frame checks Fatal, stops, cancels, frees and rebuilds | ADR-0001 | ✅ Covered |
| TR-hud-007 | battle-hud.md | Battle HUD | Presentation | Armed buttons go Hidden, Arming, Armed on a real-time advance(ms) clock clamped to 100 ms and frozen while Paused | ADR-0004 | ✅ Covered |
| TR-hud-008 | battle-hud.md | Battle HUD | Presentation | The build arc registers and unregisters resolver targets on open and close, disables Start/Call while open, and closes on outcome, Paused or Fatal | ADR-0008 | ✅ Covered |
| TR-hud-009 | battle-hud.md | Battle HUD | Presentation | The resolver's pressed payload exposes both best_tap and best_drag so the HUD can ignore a Start/Call tap that also hits the hero | ADR-0008 | ✅ Covered |
| TR-hud-010 | battle-hud.md | Battle HUD | Presentation | The HUD reads Flow, Tower, Hero, Enemy & Wave and Combat via signals and new view-only queries; phase_changed and lives_changed join the view allowlist | ADR-0006 (signals) + ADR-0010 (B10 queries) | ✅ Covered (split) |
| TR-hud-011 | battle-hud.md | Battle HUD | Presentation | Arc open and gold_changed only mark costs dirty; HudLogic reads costs through the accessor in the next view step (frame step 3), never in a sim signal handler, and the burst wedge reads Burst cooldown through the accessor at use time with the builder-injected Burst ID; a read that finds halted() is abandoned for the Fatal screen | ADR-0005 | ✅ Covered |
| TR-hud-012 | battle-hud.md | Battle HUD | Presentation | The result screen and log come from one snapshot, taken once in the first frame step 3 (view step) after the outcome's tick | ADR-0006 | ✅ Covered |
| TR-hud-013 | battle-hud.md | Battle HUD | Foundation | Debug builds append JSON lines to user://run_log.jsonl through an injectable sink; a write failure is non-fatal and release builds never write | ADR-0010 (release no-write verified by ADR-0007 M4) | ✅ Covered |
| TR-hud-014 | battle-hud.md | Battle HUD | Presentation | Layout is in 540x960 field units with safe-area insets converted to field units; burst_y = clamp(888 - I_bottom, 816, 888) | ADR-0003 | ✅ Covered |
| TR-hud-015 | battle-hud.md | Battle HUD | Presentation | HUD budget about 8 (max 12) of 60 draw calls and at most 3 text draws; hit targets at least 72 units (48 dp), text at least 21 units | ADR-0011 Decisions 6, 9, 10; rest: M9a (desktop windowed) and M9b (phone) counts | ⚠️ Partial |
| TR-hud-016 | battle-hud.md | Battle HUD | Foundation | Content tests enforce HUD layout rules (slot bounds, clearances, at most 3 next-wave types, 6 waves, 10 lives) | ADR-0002 | ✅ Covered |

## Known Gaps
None. No requirement lacks an Accepted ADR.

### Partial rows and who owns the rest
- TR-data-003: ADR-0002 X2, the Android export proof, on a device at Technical Setup.
- TR-data-015: ADR-0002 P1 and P2, device load timings at the first phone build (QQ-11).
- TR-input-006: Android gesture insets, owed to the Mobile Platform & Performance GDD, which does not exist yet (QQ-21).
- TR-combat-013: ADR-0009 P2 `bench_targeting` in a release export, and ADR-0004 V13 on the phone.
- TR-hud-015: ADR-0011 M9a (desktop windowed) and M9b (phone), the draw-call and text-batch counts.

## Superseded Requirements
None superseded or deprecated. GDD wording changed after the ADRs were written for
these rows, with the same intent; the registry text is revised (2026-11-05):
- TR-hud-001: the HUD is four pieces (Battle HUD Rule 1, ADR-0011 Decision 1): one HudTopBand `Control` with no text, HudField with all HUD text, and RangeRingView under the entities. The old text said "display-only Controls".
- TR-data-013: the content test also fails a `path_points` coordinate that a 32-bit float cannot hold exactly (Data Rule 9, ADR-0009 Decision 4).
- TR-hero-002: `BUSY` comes first, and every stat read comes before the commit with a read-time `HALTED` (Hero Rules 2 and 6, ADR-0010).
- TR-hero-012: never pinned is now proved by isolation, not by an absent HeroSim (Hero AC 28, ADR-0010 Decision 7); revised 2026-11-05 before this review.

## Changes since the third review
- New: TR-state-015 (Flow command results, Game State Rules 6 and 9, ADR-0010 Decision 2, QQ-18).
- Revised: TR-hud-001, TR-data-013, TR-hero-002 (this review); TR-hero-012 (2026-11-05, before this review).
- Coverage moved from 84 covered, 7 partial, 32 gaps of 123 to 119 covered, 5 partial, 0 gaps of 124, after ADR-0009, ADR-0010 and ADR-0011 were Accepted.
- Four rows moved from Partial to Covered (split) with ADR-0010: TR-input-014, TR-input-015, TR-tower-006, TR-hud-010.
