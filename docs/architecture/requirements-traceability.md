# Architecture Traceability Index
Last Updated: 2026-11-05 (re-checked after the ADR fix round)
Engine: Godot 4.7.2 (GDScript, Mobile renderer)

## Coverage Summary
- Total requirements: 128
- Covered by an Accepted ADR: 10 (7%)
- Covered, resting on at least one Proposed ADR: 118 (92%)
- Partial: 0
- Gaps: 0

Rebuilt on 2026-11-05 by `/architecture-review` (`architecture-review-2026-11-05.md`)
from the `GDD Requirements Addressed` table of each of the 11 ADRs, which exist
for the first time in this run. Every one of the 128 registered requirements is
cited by at least one ADR table. ADR-0001 is Accepted; ADR-0002 to ADR-0011 are
Proposed, and a requirement that any Proposed ADR decides part of is marked
🟡, which is not a pass state: the route out is
`/architecture-decision accept ADR-NNNN`. "(text)" after an ADR means its
decision text covers the requirement but its table does not cite the ID. A note
after the ADR list names an owed measurement or a cross-ADR conflict from the
review report (C1, C3 and C4 blocking, C2 an unstated trigger, D-numbers drift).

Re-checked on 2026-11-05 by `architecture-review-2026-11-05b.md` after the
ADR fix round: C1 to C4 closed, coverage unchanged (128 IDs, all cited). Two
new blocking findings sit on rows that cite ADR-0007 or ADR-0011: a
dependency cycle between those two ADRs (CY1) and conflict C5 (lint L34's
path). Notes below name C5 where it applies.

Changes in this run: TR-combat-015, TR-hero-016 and TR-hud-018 registered (they
were provisional in `architecture.md` v4). No requirement was reworded,
deprecated or renumbered; the registry wording edits the ADRs and this review
list are left for `/architecture-decision accept`.

By system: Data & Config 15, Input & Gesture Resolver 16, Game State & Stage Flow 16, Combat & Damage 15, Enemy & Wave 17, Tower System 15, Hero System 16, Battle HUD 18.
By ADR (a requirement shared by several ADRs counts under each): ADR-0001 17, ADR-0002 12, ADR-0003 11, ADR-0004 21, ADR-0005 8, ADR-0006 10, ADR-0007 7, ADR-0008 11, ADR-0009 20, ADR-0010 18, ADR-0011 8.

## Full Matrix
| Requirement ID | GDD | System | Layer | Requirement | ADR Coverage | Status |
|---|---|---|---|---|---|---|
| TR-data-001 | data-config-pipeline.md | Data & Config | Foundation | Typed read-only records keyed by a stable snake_case ID unique across all record types; records reference each other by typed ID, never by file path | ADR-0002 | 🟡 Covered (Proposed) |
| TR-data-002 | data-config-pipeline.md | Data & Config | Foundation | The storage format, or a check on top of it, detects a missing field, a fractional integer and an unknown property | ADR-0002 | 🟡 Covered (Proposed) |
| TR-data-003 | data-config-pipeline.md | Data & Config | Foundation | The catalogue loads from an explicit manifest of data files, never a directory scan, and loads correctly from an Android export | ADR-0002. Android export proof owed (ADR-0002 Verification 1) | 🟡 Covered (Proposed) |
| TR-data-004 | data-config-pipeline.md | Data & Config | Foundation | Loading is once and all-or-nothing (Unloaded, Loading, Ready/Failed), started by the app root before the first gameplay scene, with no reload | ADR-0001, ADR-0002 (text). synchronous load is ADR-0002 Decision 7 (decision text; not in its table) | 🟡 Covered (Proposed) |
| TR-data-005 | data-config-pipeline.md | Data & Config | Foundation | The validator collects every error as {code, source, record_id, field} before failing, in tiers (manifest, finiteness, bounds, tags, references), and checks the Input record's cross-field tap_slop > drag_slop at load | ADR-0002 | 🟡 Covered (Proposed) |
| TR-data-006 | data-config-pipeline.md | Data & Config | Foundation | No fallbacks in any build; a load failure shows a catalogue-free fatal screen that never opens saves, and dev runs name each error | ADR-0001, ADR-0002 (text). per-field error text is ADR-0002 Decision 9 (decision text) | 🟡 Covered (Proposed) |
| TR-data-007 | data-config-pipeline.md | Data & Config | Foundation | Definitions are read-only after load and mutable state lives on runtime instances holding def_id; a deep-snapshot test proves the catalogue is unchanged after a battle | ADR-0002, ADR-0009 (text), ADR-0010 (text). second clause (state on instances holding def_id) decided in ADR-0009 and ADR-0010 text; neither table cites the TR | 🟡 Covered (Proposed) |
| TR-data-008 | data-config-pipeline.md | Data & Config | Foundation | Every modifiable value is read through one stat accessor (read_context, stat_key) at use time, never cached, so Stat & Modifier Resolution can replace its internals with no call-site change | ADR-0005 | 🟡 Covered (Proposed) |
| TR-data-009 | data-config-pipeline.md | Data & Config | Foundation | A bad accessor call goes to an injected, test-replaceable failure handler that survives release builds (not assert) | ADR-0001, ADR-0005 (text). ADR-0005 row "Rule 10 bad calls" carries no TR id | 🟡 Covered (Proposed) |
| TR-data-010 | data-config-pipeline.md | Data & Config | Foundation | Data owns the stat-key vocabulary and int/float type per key, and exposes non-fatal level_count(def_id) and is_tower(id) | ADR-0005 | 🟡 Covered (Proposed) |
| TR-data-011 | data-config-pipeline.md | Data & Config | Foundation | No autoload or global: the app root holds the Ready catalogue across retries and the battle builder injects it | ADR-0001 | ✅ Covered |
| TR-data-012 | data-config-pipeline.md | Data & Config | Foundation | Logic tests build fixture catalogues in code with no file I/O; a separate integration suite validates the real data files | ADR-0007 | 🟡 Covered (Proposed) |
| TR-data-013 | data-config-pipeline.md | Data & Config | Foundation | A CI content test opens each Stage scene_ref, applies layout and wave rules, and checks rationale fields and owning-GDD balance ranges | ADR-0002 | 🟡 Covered (Proposed) |
| TR-data-014 | data-config-pipeline.md | Data & Config | Foundation | The data store emits no signals; each emitter declares its own and the composition root wires them | ADR-0006 | 🟡 Covered (Proposed) |
| TR-data-015 | data-config-pipeline.md | Data & Config | Foundation | Load-time targets: Loading to Ready median at most 1000 ms on an Adreno 5xx-class device; edit-to-in-game at most 10 s | ADR-0002. unmeasured until a phone build (ADR-0002 Verification 4) | 🟡 Covered (Proposed) |
| TR-input-001 | input-gesture-resolver.md | Input & Gesture | Foundation | The resolver is a pure, scene-free, clock-free object driven only by press, move, release, cancel_pointer and cancel | ADR-0008 | 🟡 Covered (Proposed) |
| TR-input-002 | input-gesture-resolver.md | Input & Gesture | Foundation | One thin adapter node is the only engine-facing input code; it maps Godot touch and mouse events to the five calls in 540x960 field units | ADR-0003 | 🟡 Covered (Proposed) |
| TR-input-003 | input-gesture-resolver.md | Input & Gesture | Foundation | Every forwarded press is followed by a release or cancel for that index, and the first closes it, even under a mouse_filter STOP Control; the canceled flag is honoured | ADR-0003 | 🟡 Covered (Proposed) |
| TR-input-004 | input-gesture-resolver.md | Input & Gesture | Foundation | The adapter runs PROCESS_MODE_ALWAYS and calls cancel() on app pause, focus loss and viewport resize, forwarding one lifecycle signal to Game State | ADR-0003 | 🟡 Covered (Proposed) |
| TR-input-005 | input-gesture-resolver.md | Input & Gesture | Foundation | Touch and mouse use one event family: emulation settings stop duplicate presses, the mouse pointer index never collides with touch index 0, non-left buttons are dropped | ADR-0003 | 🟡 Covered (Proposed) |
| TR-input-006 | input-gesture-resolver.md | Input & Gesture | Foundation | The adapter rejects presses inside edge_reject_margin and platform safe-area insets via DisplayServer.get_display_safe_area(), converted to field units | ADR-0003 | 🟡 Covered (Proposed) |
| TR-input-007 | input-gesture-resolver.md | Input & Gesture | Foundation | A registry of disc hit targets {id, centre, radius, accepts, priority, enabled, sink}; register, unregister, set_centre and set_enabled are legal in any state and apply at once | ADR-0008 | 🟡 Covered (Proposed) |
| TR-input-008 | input-gesture-resolver.md | Input & Gesture | Foundation | A four-state machine (Idle, Pressed, Dragging, Dead) with one active pointer freezes TAP and DRAG winners at press and classifies by per-press slop | ADR-0008 | 🟡 Covered (Proposed) |
| TR-input-009 | input-gesture-resolver.md | Input & Gesture | Foundation | Signal API pressed, tapped, ground_tapped, drag_started, drag_moved, drag_ended, drag_cancelled, became_idle; every exit to Idle emits became_idle() last | ADR-0008 | 🟡 Covered (Proposed) |
| TR-input-010 | input-gesture-resolver.md | Input & Gesture | Foundation | State commits before emit; gesture calls made inside a handler queue FIFO and drain synchronously in the outermost call | ADR-0008 | 🟡 Covered (Proposed) |
| TR-input-011 | input-gesture-resolver.md | Input & Gesture | Foundation | Slops come by injection through static validate() and a create() factory returning null on bad input, and a null create() in the wrapper calls the failure handler; non-finite positions are dropped with push_error | ADR-0008 | 🟡 Covered (Proposed) |
| TR-input-012 | input-gesture-resolver.md | Input & Gesture | Foundation | The battle wrapper builds the resolver and adapter per battle from the Input record and injects the one resolver into the Hero, Tower and HUD input objects; hit radii (36 to 56) are constants on those objects, not catalogue fields | ADR-0001, ADR-0010 | 🟡 Covered (Proposed) |
| TR-input-013 | input-gesture-resolver.md | Input & Gesture | Presentation | Burst button, build arc and world targets are resolver discs, not Controls; HUD Controls consume their events before the adapter, so routing order is fixed | ADR-0003 | 🟡 Covered (Proposed) |
| TR-input-014 | input-gesture-resolver.md | Input & Gesture | Foundation | Identical call lists give identical signal logs; tests use a recording fake, not assert_signal; bots call commands directly plus one resolver equivalence test | ADR-0007 | 🟡 Covered (Proposed) |
| TR-input-015 | input-gesture-resolver.md | Input & Gesture | Feature | Dev builds carry a gesture-log harness recording device, insets, timing, travel, winners and classification, listening to tower_upgraded, chip_state() at tower prompts and burst_started (only it counts as a burst), for the Pillar 4 phone test | ADR-0008, ADR-0010 | 🟡 Covered (Proposed) |
| TR-input-016 | input-gesture-resolver.md | Input & Gesture | Foundation | Minimum width 360 dp by runtime guard; stretch mode keeps field units equal to viewport units, no Camera2D, and a cancel() on resize | ADR-0003 | 🟡 Covered (Proposed) |
| TR-state-001 | game-state-stage-flow.md | Game State & Flow | Foundation | A minimal main-scene app root with no autoload triggers the catalogue load, holds the Ready catalogue, owns the fatal screen, and alone survives a retry | ADR-0001 | ✅ Covered |
| TR-state-002 | game-state-stage-flow.md | Game State & Flow | Foundation | A scene-free builder build(catalogue, stage_id, seed, fatal_handler) wires every battle system by explicit signal connections and runs headless, calling the handler and returning null when the stage cannot be built; a thin wrapper adds tick loop, resolver, adapter and views | ADR-0001 | ✅ Covered |
| TR-state-003 | game-state-stage-flow.md | Game State & Flow | Foundation | Simulation time enters only through battle.tick(dt) at a fixed rate; no _process, Timers, await, wall clock or physics areas in gameplay; the wrapper clamps owed ticks | ADR-0004 | 🟡 Covered (Proposed) |
| TR-state-004 | game-state-stage-flow.md | Game State & Flow | Foundation | Systems tick in one fixed documented order and player and bot commands apply only between ticks | ADR-0004 | 🟡 Covered (Proposed) |
| TR-state-005 | game-state-stage-flow.md | Game State & Flow | Foundation | All randomness comes from an injected seed so stage, seed and command script give an identical result | ADR-0004 | 🟡 Covered (Proposed) |
| TR-state-006 | game-state-stage-flow.md | Game State & Flow | Core | Flow and lives are a pure stage state machine (Build, Wave, Intermission, Paused, Won, Lost, and Fatal as an absorbing state) with a result readable after the outcome; in_build() is true in Build and in Paused from Build; last wave started is Enemy & Wave's wave_index() | ADR-0004 | 🟡 Covered (Proposed) |
| TR-state-007 | game-state-stage-flow.md | Game State & Flow | Core | Every transition commits state, then acts, then emits in a fixed order, and stops emitting if Fatal latched during an emit; phase fires on every state change; Won, Lost, Paused and Fatal stop the clock and cancel input before they emit; remaining systems skip the rest of that tick | ADR-0004 | 🟡 Covered (Proposed) |
| TR-state-008 | game-state-stage-flow.md | Game State & Flow | Core | Flow listens to synchronous wave_cleared, waves_completed and enemy_leaked (leak before complete) and emits lives_changed, phase and wave_called_early | ADR-0006 | 🟡 Covered (Proposed) |
| TR-state-009 | game-state-stage-flow.md | Game State & Flow | Foundation | Retry destroys the whole battle and builds a new one between ticks, driven by a latch on the app root; a weakref to the old battle must be null | ADR-0001 | ✅ Covered |
| TR-state-010 | game-state-stage-flow.md | Game State & Flow | Foundation | Focus loss or backgrounding enters Paused: ticks stop, input cancels, the accumulator is zeroed, and a resume tap reaches nothing beneath | ADR-0003 | 🟡 Covered (Proposed) |
| TR-state-011 | game-state-stage-flow.md | Game State & Flow | Foundation | One idempotent fatal handler keeps the first cause, overrides Won, Lost and Paused, latches, halts the tick and discards a partial build; the wrapper checks the latch after each assembly step; load failure, bad accessor call, a stage scene that fails to load and a null resolver create all reach it; the fatal screen is guaranteed to load | ADR-0001 | ✅ Covered |
| TR-state-012 | game-state-stage-flow.md | Game State & Flow | Core | Authored durations become whole ticks through one to_ticks conversion; countdowns are integer tick counters | ADR-0004 | 🟡 Covered (Proposed) |
| TR-state-013 | game-state-stage-flow.md | Game State & Flow | Foundation | Tests can enumerate a battle's systems, inject recording fakes, snapshot a battle, and fail when any battle signal has no listener (views on an allowlist) | ADR-0007 (C4 closed 2026-11-05: setup(battle, dev_telemetry) builds both shapes in one process) | 🟡 Covered (Proposed) |
| TR-state-014 | game-state-stage-flow.md | Game State & Flow | Presentation | Wrapper-side presentation timers (Lost delay, Won beat, button arming) run on the frame clock outside the simulation | ADR-0004 | 🟡 Covered (Proposed) |
| TR-state-015 | game-state-stage-flow.md | Game State & Flow | Foundation | The battle holds a strong typed field for every helper build creates (each system, the FatalLatch, one StatAccessor per battle) and the builder holds nothing, because a method Callable or signal connection does not keep a RefCounted target alive and .call() on a dead one aborts the caller (observed on the 4.7.2 editor; export and phone unverified) | ADR-0001 | ✅ Covered |
| TR-state-016 | game-state-stage-flow.md | Game State & Flow | Foundation | cancel_input() is a public Battle method guarded with is_valid(), set by the wrapper through set_input_cancel; Flow calls it on Won, Lost, Paused and Fatal and the app root before removing a battle on retry; it does nothing headless, and a second call finds the resolver Idle | ADR-0001 | ✅ Covered |
| TR-combat-001 | combat-damage.md | Combat & Damage | Core | Combat is three pieces: a DamageEvent value (target, amount, source_kind, source_id), one Health and one Status per enemy; no ProjectileSpawner | ADR-0009 | 🟡 Covered (Proposed) |
| TR-combat-002 | combat-damage.md | Combat & Damage | Core | The enemy object exposes spawn_id, cached distance and position, and removed, and stays a valid reference after removal, so it cannot be a freed Node | ADR-0009 | 🟡 Covered (Proposed) |
| TR-combat-003 | combat-damage.md | Combat & Damage | Core | Every HP change goes through deliver(event) inside a tick, applying min(amount, hp) after guards in fixed order with named push_error codes | ADR-0009 | 🟡 Covered (Proposed) |
| TR-combat-004 | combat-damage.md | Combat & Damage | Core | Death is immediate at HP 0 or below; dead enemies cannot be targeted; the reap step removes the corpse and emits enemy_killed(bounty) once | ADR-0009 | 🟡 Covered (Proposed) |
| TR-combat-005 | combat-damage.md | Combat & Damage | Core | Per-source damage counters expose dealt_by_id, dealt_by_kind, dealt_total and hero_share, readable until the battle is destroyed | ADR-0009 | 🟡 Covered (Proposed) |
| TR-combat-006 | combat-damage.md | Combat & Damage | Core | Slow is per-instance whole-tick countdown state with replace/equal/ignore rules; movement multiplies move_speed by speed_factor(enemy) | ADR-0009 | 🟡 Covered (Proposed) |
| TR-combat-007 | combat-damage.md | Combat & Damage | Core | Combat reads no catalogue data; callers pass values in and its only dependency is the pure to_ticks with dt injected | ADR-0005 (text), ADR-0009. ADR-0005 row "Rule 9" carries no TR id | 🟡 Covered (Proposed) |
| TR-combat-008 | combat-damage.md | Combat & Damage | Core | Pure targeting helpers first_in, nearest_in and all_in_radius use an inclusive squared-distance test, tie-break by lowest spawn_id and never mutate input | ADR-0009 | 🟡 Covered (Proposed) |
| TR-combat-009 | combat-damage.md | Combat & Damage | Foundation | Tick order is Flow, Enemy & Wave advance, tick_status, Towers by slot, Hero then burst, reap; leaks resolve before fire | ADR-0004 | 🟡 Covered (Proposed) |
| TR-combat-010 | combat-damage.md | Combat & Damage | Core | View-only attack_fired and damage_applied emit after commit with copied positions; listeners never call deliver, and results match with or without listeners | ADR-0006 (C1 closed 2026-11-05: EnemyView is on the damage_applied row) | 🟡 Covered (Proposed) |
| TR-combat-011 | combat-damage.md | Combat & Damage | Presentation | The Combat view draws primitives from one _draw() per kind with no shaders or particles and a 16-marker flash pool on the frame clock | ADR-0011 | 🟡 Covered (Proposed) |
| TR-combat-012 | combat-damage.md | Combat & Damage | Foundation | Errors use push_error, asserted with gdUnit4 assert_error().is_push_error() and the push_error report setting on; invariant I checks damage sums | ADR-0007. push_error report setting name open (ADR-0007 V5) | 🟡 Covered (Proposed) |
| TR-combat-013 | combat-damage.md | Combat & Damage | Core | Per-tick targeting stays within budget on a low-end phone at the catch-up clamp (about 400 range checks, under 2 ms, unmeasured) | ADR-0009. unmeasured (ADR-0009 Verification 2) | 🟡 Covered (Proposed) |
| TR-combat-014 | combat-damage.md | Combat & Damage | Foundation | Determinism holds per CPU architecture only; bot baselines are kept per architecture | ADR-0004 | 🟡 Covered (Proposed) |
| TR-combat-015 | combat-damage.md | Combat & Damage | Presentation | The Combat view's burst clearance runs from burst_started to 0.15 s of frame-clock time after the next BURST attack_fired, ends at a phase_changed to Won, Lost or Fatal if the burst never released, and ignores every other phase_changed, Paused included | ADR-0011 | 🟡 Covered (Proposed) |
| TR-enemy-001 | enemy-wave.md | Enemy & Wave | Foundation | The Stage record holds gameplay geometry (path_points, slot_positions, path_width, requires_bend, early_call_seconds_per_gold); the scene holds only the look | ADR-0002 | 🟡 Covered (Proposed) |
| TR-enemy-002 | enemy-wave.md | Enemy & Wave | Foundation | Fixed tick dt with one to_ticks (round half away from zero); spawn ticks come from an absolute schedule, never a float countdown | ADR-0004 | 🟡 Covered (Proposed) |
| TR-enemy-003 | enemy-wave.md | Enemy & Wave | Core | Enemy & Wave has two tick entries, advance (spawn, move, leak) and reap, in Combat's tick order; the battle passes the roster to tick_status | ADR-0004 | 🟡 Covered (Proposed) |
| TR-enemy-004 | enemy-wave.md | Enemy & Wave | Core | enemy_leaked, enemy_killed, wave_cleared and waves_completed fire synchronously (no CONNECT_DEFERRED) in spawn_id order after commit; leaks come before the clear | ADR-0006 | 🟡 Covered (Proposed) |
| TR-enemy-005 | enemy-wave.md | Enemy & Wave | Core | The builder injects a halted() callable checked after every accessor read and signal; the system never references Flow | ADR-0001 | ✅ Covered |
| TR-enemy-006 | enemy-wave.md | Enemy & Wave | Foundation | Every enemy stat is read through the accessor at use time with a reused per-enemy read context; Wave and Stage records are read directly and never written | ADR-0005 | 🟡 Covered (Proposed) |
| TR-enemy-007 | enemy-wave.md | Enemy & Wave | Foundation | Waves use no randomness and never read the sim seed; cosmetic jitter uses a separate RNG; retry rebuilds identical spawn_id and schedule | ADR-0004 | 🟡 Covered (Proposed) |
| TR-enemy-008 | enemy-wave.md | Enemy & Wave | Core | The roster solely owns its enemies, exposes read-only roster() and targets() in spawn_id order, and enemies keep no back-references so retry frees them | ADR-0009 | 🟡 Covered (Proposed) |
| TR-enemy-009 | enemy-wave.md | Enemy & Wave | Core | How Health and Status attach to an enemy (spawn_id, def_id, distance, position, removed) is decided by ADR | ADR-0009 | 🟡 Covered (Proposed) |
| TR-enemy-010 | enemy-wave.md | Enemy & Wave | Core | Position comes from distance along a polyline via a cached cumulative-length array, crossing several segments per step and clamped to the end | ADR-0009 | 🟡 Covered (Proposed) |
| TR-enemy-011 | enemy-wave.md | Enemy & Wave | Core | An enemy is targetable only while its centre is inside the 540x960 field rectangle, a defined constant or injected value | ADR-0009 | 🟡 Covered (Proposed) |
| TR-enemy-012 | enemy-wave.md | Enemy & Wave | Core | Wave control is a Waiting/Active/Finished machine with start_next_wave() logging to an injected dev-error sink, not assert | ADR-0001, ADR-0009 | 🟡 Covered (Proposed) |
| TR-enemy-013 | enemy-wave.md | Enemy & Wave | Core | One add-enemy step handles schedule spawns and future splitter children, joining atomically before the clear check | ADR-0009 | 🟡 Covered (Proposed) |
| TR-enemy-014 | enemy-wave.md | Enemy & Wave | Foundation | A headless content test checks layout rules L1-L14 and wave rules on in-memory records; unit tests use fakes and no scene or files | ADR-0007 | 🟡 Covered (Proposed) |
| TR-enemy-015 | enemy-wave.md | Enemy & Wave | Presentation | Views read roster() and the path each frame; fixed three-pass draw order; a view pool of at least 48 that grows with a dev error; Reduce Motion honoured | ADR-0011. ADR-0011 Decision 16 also decides Enemy & Wave criterion 57 (danger rule), which has no TR | 🟡 Covered (Proposed) |
| TR-enemy-016 | enemy-wave.md | Enemy & Wave | Core | wave_index() is the 1-based position in wave_ids of the last wave started, 0 before any start and never reset per wave; Flow reads it for the result and the HUD for pips and result text | ADR-0009 | 🟡 Covered (Proposed) |
| TR-enemy-017 | enemy-wave.md | Enemy & Wave | Core | got_through_by_type() counts a leak before enemy_leaked fires, so a fatal leak is in the result | ADR-0009 | 🟡 Covered (Proposed) |
| TR-tower-001 | tower-system.md | Tower | Core | TowerSim (builder-made, headless) holds gold, slots, towers and the tick; TowerInput (wrapper-made, absent headless) changes state only through upgrade | ADR-0010 | 🟡 Covered (Proposed) |
| TR-tower-002 | tower-system.md | Tower | Core | build(slot_index, tower_id) and upgrade(slot_index) are the only mutation API, run between ticks and return a typed result enum in fixed check order | ADR-0010 (C3 closed 2026-11-05: ADR-0001 Decision 8 amended, HALTED is ordinary) | 🟡 Covered (Proposed) |
| TR-tower-003 | tower-system.md | Tower | Foundation | Tower IDs and levels are validated with is_tower and level_count before any accessor read; cost and stats are read at use time | ADR-0005 | 🟡 Covered (Proposed) |
| TR-tower-004 | tower-system.md | Tower | Core | Command commit is atomic: state commits before gold_changed then tower_built or tower_upgraded; a refusal changes and emits nothing | ADR-0006 | 🟡 Covered (Proposed) |
| TR-tower-005 | tower-system.md | Tower | Core | Towers tick in ascending slot index; cooldown_left is an integer tick counter that runs on every tick, Intermission included | ADR-0004 | 🟡 Covered (Proposed) |
| TR-tower-006 | tower-system.md | Tower | Core | The injected halted() is checked after every read and signal; all stats are read before any mutation so a bad read halts with nothing half done | ADR-0001, ADR-0010 | 🟡 Covered (Proposed) |
| TR-tower-007 | tower-system.md | Tower | Core | Targeting and damage go only through Combat's API; splash victims come only from targets() | ADR-0009 | 🟡 Covered (Proposed) |
| TR-tower-008 | tower-system.md | Tower | Core | Gold is one non-negative integer owned by TowerSim, fed by starting_gold, enemy_killed(bounty) and wave_called_early; gold freezes once halted | ADR-0010 | 🟡 Covered (Proposed) |
| TR-tower-009 | tower-system.md | Tower | Core | The early-call bonus is one pure integer function early_call_bonus(seconds_left), to_ticks(seconds_left) div to_ticks(rate), shared by the payout and the HUD's Call +N; seconds_left includes the tick the next wave starts on | ADR-0010 | 🟡 Covered (Proposed) |
| TR-tower-010 | tower-system.md | Tower | Feature | The upgrade chip window runs on real time while the sim clock is stopped, via a pure ChipWindow.advance(ms) fed by the wrapper | ADR-0004 | 🟡 Covered (Proposed) |
| TR-tower-011 | tower-system.md | Tower | Feature | TowerInput registers slots and the chip disc with the resolver, disables built slots, closes the chip on phase, and ignores taps while halted | ADR-0008, ADR-0010 | 🟡 Covered (Proposed) |
| TR-tower-012 | tower-system.md | Tower | Core | Signals have typed signatures (tower_id type undecided); gameplay may not depend on them and results match with or without listeners | ADR-0006 | 🟡 Covered (Proposed) |
| TR-tower-013 | tower-system.md | Tower | Core | Retry teardown leaves no old battle alive through a signal connection; a listener-count wiring test names any missing connection | ADR-0001, ADR-0007 (text). listener-count test mechanism is ADR-0007 Decision 5 (decision text) | 🟡 Covered (Proposed) |
| TR-tower-014 | tower-system.md | Tower | Foundation | All logic is unit-testable headless with spy accessor, recording fake and fake halted(); the content test enforces tower and gold rows | ADR-0007 | 🟡 Covered (Proposed) |
| TR-tower-015 | tower-system.md | Tower | Presentation | All towers draw from one _draw() node with primitive polygons, level inset and a cooldown ring, with Reduce Motion fallbacks | ADR-0011 | 🟡 Covered (Proposed) |
| TR-hero-001 | hero-system.md | Hero | Core | Hero splits into HeroSim (builder-made, headless) and HeroInput (wrapper-only), which changes battle state only through pin() and burst() | ADR-0010 | 🟡 Covered (Proposed) |
| TR-hero-002 | hero-system.md | Hero | Core | pin() and burst() run between ticks and return ordered enum result codes, state checked before geometry; a refusal mutates nothing | ADR-0010 (C3 closed 2026-11-05: ADR-0001 Decision 8 amended, HALTED is ordinary) | 🟡 Covered (Proposed) |
| TR-hero-003 | hero-system.md | Hero | Core | HeroSim ticks in the Hero-and-burst slot (walk, attack, cooldown, telegraph, release), uses to_ticks, and returns at once when halted() | ADR-0004 | 🟡 Covered (Proposed) |
| TR-hero-004 | hero-system.md | Hero | Core | The builder injects halted(), in_build(), the hand flag, the Hero record ID and burst_id into HeroSim; the wrapper injects the same reads from Battle into HeroInput and HudLogic, including the Burst ID for the cooldown wedge (ADR-0001 Decision 3) | ADR-0001 | ✅ Covered |
| TR-hero-005 | hero-system.md | Hero | Foundation | Hero and Burst stats are read through the accessor at use time; hero_start, pin_rect and pin_exclusion come straight from the Stage record | ADR-0005 | 🟡 Covered (Proposed) |
| TR-hero-006 | hero-system.md | Hero | Core | PinGeometry is a plain scene-free class computing in float scalars only (no Vector2 methods) with stated tolerances and tie-breaks | ADR-0004 | 🟡 Covered (Proposed) |
| TR-hero-007 | hero-system.md | Hero | Core | Hero uses deliver with HERO/BURST source kinds, report_attack before deliver, and nearest_in, all_in_radius, is_dead, hp_left over targets() | ADR-0009 | 🟡 Covered (Proposed) |
| TR-hero-008 | hero-system.md | Hero | Core | hero_pinned and burst_started emit after state is set and are on Flow's view allowlist; handlers never issue commands | ADR-0006 | 🟡 Covered (Proposed) |
| TR-hero-009 | hero-system.md | Hero | Core | HeroSim exposes read-only queries and per-run counters (repins, bursts, victims, kills) for HUD, bots, logs and Stage Progression | ADR-0010 | 🟡 Covered (Proposed) |
| TR-hero-010 | hero-system.md | Hero | Presentation | HeroInput registers hero DRAG, button DRAG and sink TAP discs, updates the walking hero's hit centre each frame, and hit-tests cancel hysteresis | ADR-0008, ADR-0010 | 🟡 Covered (Proposed) |
| TR-hero-011 | hero-system.md | Hero | Presentation | HeroInput's aim state machine and cooldown_digit() advance through an explicit update(), not engine frames | ADR-0004, ADR-0010 (D2 closed 2026-11-05: both name HeroInput.update() in frame step b) | 🟡 Covered (Proposed) |
| TR-hero-012 | hero-system.md | Hero | Core | A resolver-driven script and a direct-command script give tick-identical HeroSim state; a never-pinned run equals a HeroSim-absent run | ADR-0010 | 🟡 Covered (Proposed) |
| TR-hero-013 | hero-system.md | Hero | Core | Pause stops the sim clock so walk and telegraph resume exactly; aims get drag_cancelled; Build runs no ticks, so a pin in Build places the hero at once through in_build(); Intermission ticks | ADR-0004 | 🟡 Covered (Proposed) |
| TR-hero-014 | hero-system.md | Hero | Foundation | Content tests enforce hero and burst rules (leash, telegraph, intermission, reach, hero_start, pin_exclusion, one Hero record), each proven on a broken fixture | ADR-0002 | 🟡 Covered (Proposed) |
| TR-hero-015 | hero-system.md | Hero | Presentation | burst_button_centre() is owned by the HUD, read once by HeroInput at registration, and injectable by tests | ADR-0010 | 🟡 Covered (Proposed) |
| TR-hero-016 | hero-system.md | Hero System | Core | A telegraph in flight when halted() latches never releases (no BURST attack_fired); because the Hero slot precedes the reap, a burst that kills the last enemy releases on the Won tick and its BURST attack_fired precedes phase_changed(Won); the hero view's outcome rows run on the frame clock | ADR-0004, ADR-0011 | 🟡 Covered (Proposed) |
| TR-hud-001 | battle-hud.md | Battle HUD | Presentation | The HUD is HudLogic (plain, the only part that decides, registers every HUD disc and issues every command), HudTopBand (display-only Controls), HudField (one _draw, no targets) and HudModals (result and Paused Controls), built before HeroInput, absent headless and rebuilt on retry | ADR-0011 | 🟡 Covered (Proposed) |
| TR-hud-002 | battle-hud.md | Battle HUD | Presentation | Result and Paused screens are full-screen modal Controls, built once and toggled visible, that consume every event before the Input adapter sees it; a modal is only hidden inside its own handler, never freed | ADR-0003 | 🟡 Covered (Proposed) |
| TR-hud-003 | battle-hud.md | Battle HUD | Presentation | HudLogic's modal press model repeats the adapter's rules: a press inside edge_reject_margin or an inset does not count, a tap counts only on the same pointer's release within tap_slop while Armed, a later press replaces an unmoved one, and lifecycle or focus-loss signals clear it | ADR-0003 | 🟡 Covered (Proposed) |
| TR-hud-004 | battle-hud.md | Battle HUD | Presentation | The HUD holds presentation state only and no reset path; full sim state is identical with or without the HUD | ADR-0006 | 🟡 Covered (Proposed) |
| TR-hud-005 | battle-hud.md | Battle HUD | Core | Each frame runs input commands, then real-time models, then ticks, then views, so the displayed bonus equals the paid bonus | ADR-0004 | 🟡 Covered (Proposed) |
| TR-hud-006 | battle-hud.md | Battle HUD | Foundation | Retry sets an idempotent latch on the app root and never frees its caller; the root's next frame checks Fatal, stops, cancels, frees and rebuilds | ADR-0001 | ✅ Covered |
| TR-hud-007 | battle-hud.md | Battle HUD | Presentation | Armed buttons go Hidden, Arming, Armed on a real-time advance(ms) clock clamped to 100 ms and frozen while Paused | ADR-0004 | 🟡 Covered (Proposed) |
| TR-hud-008 | battle-hud.md | Battle HUD | Presentation | The build arc registers and unregisters resolver targets on open and close, disables Start/Call while open, and closes on outcome, Paused or Fatal | ADR-0008, ADR-0010 | 🟡 Covered (Proposed) |
| TR-hud-009 | battle-hud.md | Battle HUD | Presentation | The resolver's pressed payload exposes both best_tap and best_drag so the HUD can ignore a Start/Call tap that also hits the hero | ADR-0008 | 🟡 Covered (Proposed) |
| TR-hud-010 | battle-hud.md | Battle HUD | Presentation | The HUD reads Flow, Tower, Hero, Enemy & Wave and Combat via signals and view-only queries (wave_index(), got_through_by_type(), chip_state(), early_call_bonus(), tower_inspected, hero_pinned, tower_built); the burst wedge is the float burst_wedge formula over cooldown_left() and Burst cooldown, read through the accessor with the injected Burst ID when Cooling begins; phase and lives_changed join the view allowlist | ADR-0006 | 🟡 Covered (Proposed) |
| TR-hud-011 | battle-hud.md | Battle HUD | Presentation | Costs are read through the accessor on arc open and gold_changed; a read or snapshot that finds phase() Fatal is abandoned for the Fatal screen (halted() is not the test, since it is also true on Won and Lost) | ADR-0005 | 🟡 Covered (Proposed) |
| TR-hud-012 | battle-hud.md | Battle HUD | Presentation | The result screen and log come from one snapshot built on the first advance(ms) after the outcome, never inside the tick's signal stack; no snapshot is built if phase() is Fatal | ADR-0006 | 🟡 Covered (Proposed) |
| TR-hud-013 | battle-hud.md | Battle HUD | Foundation | Debug builds append JSON lines to user://run_log.jsonl through an injectable sink; a write failure is non-fatal and release builds never write | ADR-0010 (C4 closed 2026-11-05). conflict C5: ADR-0007 L34 scans src/battle/run_log.gd, ADR-0010 places RunLog in src/presentation/telemetry/ | 🟡 Covered (Proposed) |
| TR-hud-014 | battle-hud.md | Battle HUD | Presentation | Layout is in 540x960 field units with safe-area insets converted to field units; burst_y = clamp(888 - I_bottom, 816, 888) | ADR-0003 | 🟡 Covered (Proposed) |
| TR-hud-015 | battle-hud.md | Battle HUD | Presentation | HUD budget about 8 (max 12) of 60 draw calls and at most 3 text draws; hit targets at least 72 units (48 dp), text at least 21 units | ADR-0011. Android draw-call count unmeasured (ADR-0011 V1) | 🟡 Covered (Proposed) |
| TR-hud-016 | battle-hud.md | Battle HUD | Foundation | Content tests enforce HUD layout rules (slot bounds, clearances including the burst line at least edge_reject_margin + 48 from a side edge, at most 3 next-wave types, a next-try line per enemy type, an early-call bonus of at most 2 digits, 6 waves, 10 lives) | ADR-0002 | 🟡 Covered (Proposed) |
| TR-hud-017 | battle-hud.md | Battle HUD | Presentation | HudField redraws only when a quantised view-model key changes (every value its draw reads, including open-disc and chip affordability) and while a timed visual runs, not every frame | ADR-0011 | 🟡 Covered (Proposed) |
| TR-hud-018 | battle-hud.md | Battle HUD | Core | Debug run-log records: one attempt record (tower IDs built as a list, lives, last wave, damage by source and kind, slows_applied(), repins and its value at wave 1's start, burst counters, kills_per_burst[], best_victims, got through by type, seconds to first pin, build and burst) and one call record (attempt index, seconds_left, burst_state() and pin_state() sampled at the call, lives lost in the called wave) written at the next wave_cleared or outcome; a call pending at an outcome is written on the same advance before the attempt record; Fatal drops it | ADR-0010 (C2 closed 2026-11-05: RunLog keys on phase_changed(INTERMISSION)); architecture.md row still says wave_cleared | 🟡 Covered (Proposed) |

## Known Gaps
None. No requirement is without an ADR.

Two things sit beside the matrix and are not gaps:

- **Decided without a TR.** ADR-0011 Decision 16 decides Enemy & Wave criterion 57
  (the danger rule: 240 units, 1.5 s, `now` injected, ends on Won or Lost), which
  the registry does not hold. ADR-0005's rows "Rule 10 bad calls" and "Rule 9:
  Combat reads no data" restate TR-data-009 and TR-combat-007 without citing them.
- **Candidate requirements not registered.** The GDD fixes of 2026-11-04 and
  2026-11-05 added two statements that existing entries cover only in part:
  "Battle exposes to the wrapper what only the builder holds" (nearest
  TR-hero-004, TR-state-002; decided by ADR-0001 Decisions 3 and 4) and
  "HudLogic is Node-free, takes everything by injection and emits
  `modal_changed`" (nearest TR-hud-001, TR-hud-003, TR-hud-012; decided by
  ADR-0001 Decision 4 and ADR-0006 Decision 12). The review recommends folding
  them into those entries' wording at acceptance rather than adding
  TR-state-017 and TR-hud-019.

## Superseded Requirements
None. No GDD requirement was changed after the ADR that covers it was written.
Fourteen registry entries carry wording that trails their GDD (same intent), and
the ADRs' "GDD and Registry Sync at Acceptance" sections list further rewordings;
both lists are in `architecture-review-2026-11-05.md` and are applied by
`/architecture-decision accept`, keeping every ID.
