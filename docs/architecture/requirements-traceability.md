# Architecture Traceability Index

Last Updated: 2026-11-04
Engine: Godot 4.7.2 (GDScript, Mobile renderer)
Source: `/architecture-review` full, workflow `standard`. Report: `docs/architecture/architecture-review-2026-11-04.md`

## Coverage Summary

- Total requirements: 74 (70 from the architecture baseline, now permanent, plus 4 new)
- Covered by an Accepted ADR: 0 (0%)
- Covered by a Proposed ADR: 71 (96%)
- Partial: 3
- Gaps: 0

All 14 ADRs are `Proposed`. The user chose on 2026-11-04 to keep them so until each passes its engine checks (`production/qa/engine-verification-plan.md`). Proposed coverage is not a pass: it caps the review at CONCERNS. The route out is `/architecture-decision accept ADR-NNNN`, in dependency order, after the runs.

Status values: **Covered (Proposed)** means an ADR addresses the requirement and that ADR is still Proposed. **Partial** means an ADR addresses part of it; the note says what is missing.

## Full Matrix

| TR-ID | GDD | Requirement | ADR | Status |
|-------|-----|-------------|-----|--------|
| TR-data-001 | data-config-pipeline.md | Load the whole catalogue once from an explicit manifest before the first gameplay scene; all records valid or the game does not start | ADR-0004 | Covered (Proposed) |
| TR-data-002 | data-config-pipeline.md | Validate everything, collect all errors as `{code, source, record_id, field}`, then fail | ADR-0004 | Covered (Proposed) |
| TR-data-003 | data-config-pipeline.md | Definitions are read-only after load; runtime instances hold `def_id` (and level for towers) | ADR-0004 | Covered (Proposed) |
| TR-data-004 | data-config-pipeline.md | One stat accessor taking a read context and key, returning the declared type, with non-fatal `level_count` and `is_tower` | ADR-0004 | Covered (Proposed) |
| TR-data-005 | data-config-pipeline.md | Stage geometry (`path_points`, `slot_positions`, `path_width`, `hero_start`, `pin_rect`, `pin_exclusion`) lives on the Stage record, read directly | ADR-0004 | Covered (Proposed) |
| TR-data-006 | data-config-pipeline.md | The catalogue is injected, never an autoload; tests build fixture catalogues in code with no file I/O | ADR-0004 | Covered (Proposed) |
| TR-data-007 | data-config-pipeline.md | No fallbacks in any build; a bad accessor call reaches the failure handler and the Fatal screen | ADR-0002 | Covered (Proposed) |
| TR-data-008 | data-config-pipeline.md | A CI content test opens each `scene_ref` and applies the layout, wave and tower rules to the records | ADR-0013 | Covered (Proposed) |
| TR-data-009 | data-config-pipeline.md | Edit a value, save, run: the new value is in the game within 10 s, no live reload | ADR-0004 | Covered (Proposed) |
| TR-input-001 | input-gesture-resolver.md | One active pointer; two winners (tap, drag) frozen at press; tap and drag classified by slop; a gesture reaches only its class winner | ADR-0006 | Covered (Proposed) |
| TR-input-002 | input-gesture-resolver.md | A registry of discs with priority, accepted gestures and an enabled flag; owners register and unregister themselves | ADR-0006 | Covered (Proposed) |
| TR-input-003 | input-gesture-resolver.md | The adapter maps engine events to five calls, applies the edge reject margin, keeps receiving events while Paused (mechanism open: ADR-0002), and exposes `cancel()` for AppRoot to call on lifecycle events | ADR-0006, ADR-0002 | Covered (Proposed) |
| TR-input-004 | input-gesture-resolver.md | The resolver is clock-free and emits one `drag_moved` per input call, never per frame | ADR-0006 | Covered (Proposed) |
| TR-input-005 | input-gesture-resolver.md | The resolver is built only by the ShellBuilder; bots call commands on `Battle`; one equivalence test through the resolver | ADR-0001 | Covered (Proposed) |
| TR-input-006 | input-gesture-resolver.md | A development-build gesture log with the Rule 13 fields | ADR-0014 | Covered (Proposed) |
| TR-input-007 | input-gesture-resolver.md | All thresholds and hit radii are in field units on the 540 x 960 field; hit targets are at least 48 dp | ADR-0008 | Covered (Proposed) |
| TR-input-008 | input-gesture-resolver.md | Adapter contract: every press ends in exactly one release, cancel_pointer or cancel; the touch `canceled` flag is checked first | ADR-0006 | Covered (Proposed) |
| TR-flow-001 | game-state-stage-flow.md | The app root is a minimal main scene with no autoload; it holds the catalogue, the fatal screen, the retry latch and the presentation session flags | ADR-0002 | Covered (Proposed) |
| TR-flow-002 | game-state-stage-flow.md | `BattleBuilder.build(catalogue, stage_id, seed, fatal_handler)` constructs and wires one battle with explicit connections and no scene | ADR-0002 | Covered (Proposed) |
| TR-flow-003 | game-state-stage-flow.md | Simulation time enters only through `Battle.tick()`, one fixed 1/60 s step per call; no `_process`, engine timer, `await`, wall clock or physics area in gameplay | ADR-0003 | Covered (Proposed) |
| TR-flow-004 | game-state-stage-flow.md | A fixed system tick order; commands apply only between ticks | ADR-0003, ADR-0005 | Covered (Proposed) |
| TR-flow-005 | game-state-stage-flow.md | A phase machine (Build, Wave, Intermission, Paused, Won, Lost, Fatal) with an outcome latch and `halted()`, `in_build()`, `in_tick()` | ADR-0005 | Covered (Proposed) |
| TR-flow-006 | game-state-stage-flow.md | Lives formula `max(0, before - cost)`; leak events synchronous and before `waves_complete`; a fatal leak beats a clear | ADR-0005 | Covered (Proposed) |
| TR-flow-007 | game-state-stage-flow.md | Retry destroys and rebuilds the whole battle with the same seed, through a latch on the root, Fatal first | ADR-0002 | Covered (Proposed) |
| TR-flow-008 | game-state-stage-flow.md | Focus loss enters Paused: clock stops, input cancels, accumulator zeroed, a tap resumes | ADR-0002 | Covered (Proposed) |
| TR-flow-009 | game-state-stage-flow.md | The failure handler is idempotent, keeps the first cause, discards a partial battle, and shows a generic screen with no catalogue data | ADR-0002 | Covered (Proposed) |
| TR-flow-010 | game-state-stage-flow.md | A wiring test fails if any battle signal has no listener unless allowlisted for views | ADR-0005 | Covered (Proposed) |
| TR-flow-011 | game-state-stage-flow.md | The same stage, seed and command script give an identical result | ADR-0003 | Covered (Proposed) |
| TR-flow-012 | game-state-stage-flow.md | One conversion for authored time, `to_ticks(seconds) = round(seconds / dt)`, halves away from zero | ADR-0003 | Covered (Proposed) |
| TR-combat-001 | combat-damage.md | One damage path, `deliver(event)`, only inside a tick, returning the amount applied | ADR-0007 | Covered (Proposed) |
| TR-combat-002 | combat-damage.md | Health per enemy seeded once from `max_hp`; death is immediate; counters by source id and kind | ADR-0007 | Covered (Proposed) |
| TR-combat-003 | combat-damage.md | Status with one slow slot per enemy, held in whole ticks, no stacking | ADR-0007 | Covered (Proposed) |
| TR-combat-004 | combat-damage.md | Pure targeting helpers with exact compares, ties to the lowest `spawn_id`, skipping the dead, never modifying the list | ADR-0007 | Covered (Proposed) |
| TR-combat-005 | combat-damage.md | Combat reads no data; callers pass values in | ADR-0007, ADR-0004 | Covered (Proposed) |
| TR-combat-006 | combat-damage.md | `attack_fired` and `damage_applied` carry copied positions and feed views only | ADR-0005 | Covered (Proposed) |
| TR-combat-007 | combat-damage.md | The targeting worst case (about 400 checks) stays within about 2 ms on a low-end phone | ADR-0007 | Covered (Proposed) |
| TR-wave-001 | enemy-wave.md | One path per stage; position is computed from one distance along it; a view draws from the same points | ADR-0009 | Covered (Proposed) |
| TR-wave-002 | enemy-wave.md | An authored absolute spawn schedule in whole ticks, no randomness | ADR-0003 | Covered (Proposed) |
| TR-wave-003 | enemy-wave.md | `enemy_killed`, `enemy_leaked`, `wave_cleared`, `waves_complete` emitted synchronously; reap in ascending `spawn_id` | ADR-0005 | Covered (Proposed) |
| TR-wave-004 | enemy-wave.md | Movement `d_next = d + speed x factor x dt`; leak at path length; a guard for a bad speed | ADR-0003 | Partial |
| TR-wave-005 | enemy-wave.md | `halted()` is checked after every accessor read and every signal | ADR-0005 | Covered (Proposed) |
| TR-wave-006 | enemy-wave.md | Layout rules L1 to L14 and the wave rules run in the content test | ADR-0013 | Covered (Proposed) |
| TR-wave-007 | enemy-wave.md | An enemy is targetable only inside the field; everything outside the field is masked on any screen shape | ADR-0008 | Covered (Proposed) |
| TR-wave-008 | enemy-wave.md | At most 48 enemies alive; the view pool matches | ADR-0009, ADR-0012 | Covered (Proposed) |
| TR-wave-009 | enemy-wave.md | One add-enemy step serves the schedule and later splitter children | ADR-0009 | Covered (Proposed) |
| TR-wave-010 | enemy-wave.md | `roster()` (all not yet removed, in `spawn_id` order) and `targets()` (those inside the field) are read-only and never kept by a reader (Rule 14) | ADR-0009 | Covered (Proposed) |
| TR-wave-011 | enemy-wave.md | A height-scaled wider screen keeps at least 0.667 dp per field unit, or layout rules L1 and L6 are rechecked | ADR-0008 | Covered (Proposed) |
| TR-tower-001 | tower-system.md | TowerSim (headless) and TowerInput (wrapper only); TowerInput changes state only through `upgrade` | ADR-0010 | Covered (Proposed) |
| TR-tower-002 | tower-system.md | `build` and `upgrade` return ordered result codes, work in every phase, and are shared by players and bots | ADR-0010 | Covered (Proposed) |
| TR-tower-003 | tower-system.md | Gold is one non-negative integer; kills and early calls add, the two commands spend; the bonus is `to_ticks(seconds_left) div to_ticks(rate)` | ADR-0010 | Covered (Proposed) |
| TR-tower-004 | tower-system.md | Attack timers in integer ticks with ready-and-holding; a slow tower prefers an empty slow slot | ADR-0010 | Covered (Proposed) |
| TR-tower-005 | tower-system.md | A pure `ChipWindow` fed real milliseconds (200 to 1500) and a chip disc registered while open | ADR-0010 | Covered (Proposed) |
| TR-tower-006 | tower-system.md | Signals `gold_changed`, `tower_built`, `tower_upgraded`; wrapper-only `slot_tapped`, `tower_inspected`, `chip_state()` | ADR-0005 | Covered (Proposed) |
| TR-tower-007 | tower-system.md | Content rules: two levels, cost bounds, the bonus share, `gold_before_last_wave` below the cheapest full board | ADR-0013 | Covered (Proposed) |
| TR-hero-001 | hero-system.md | HeroSim (headless) and HeroInput (wrapper only); HeroInput changes the battle only through `pin` and `burst` | ADR-0011 | Covered (Proposed) |
| TR-hero-002 | hero-system.md | Ordered result codes for `pin` and `burst`; a straight-line walk in whole ticks; `PinGeometry.clamp` as a plain class | ADR-0011 | Covered (Proposed) |
| TR-hero-003 | hero-system.md | Aim in HeroInput with cancel hysteresis (64 and 48), recomputed every frame while the hero walks | ADR-0011 | Covered (Proposed) |
| TR-hero-004 | hero-system.md | Telegraph and cooldown in integer ticks; release in the hero slot; burst counters | ADR-0011 | Covered (Proposed) |
| TR-hero-005 | hero-system.md | The kill preview projects enemy positions to landing | ADR-0012 | Covered (Proposed) |
| TR-hero-006 | hero-system.md | Scripted bots reproduce the share gate headless on the fixed tick | ADR-0013 | Covered (Proposed) |
| TR-hud-001 | battle-hud.md | Three pieces: HudLogic (plain, testable), HudTopBand (Controls), HudField (one `_draw` plus Input discs) | ADR-0012 | Covered (Proposed) |
| TR-hud-002 | battle-hud.md | Result and Paused screens are Controls that consume every event; everything else tappable is an Input disc | ADR-0006 | Covered (Proposed) |
| TR-hud-003 | battle-hud.md | Commands run from the input call stack before the frame's ticks; Retry only sets a latch | ADR-0002 | Covered (Proposed) |
| TR-hud-004 | battle-hud.md | Real-time models run on `advance(ms)` clamped to 100 ms and ignored while Paused | ADR-0003 | Covered (Proposed) |
| TR-hud-005 | battle-hud.md | Draw budget: about 8 and at most 12 of 60 draw calls; at most 3 text draws | ADR-0012 | Covered (Proposed) |
| TR-hud-006 | battle-hud.md | A debug-only `user://run_log.jsonl` with one record per attempt and per call | ADR-0014 | Partial |
| TR-hud-007 | battle-hud.md | Layout in field units with safe-area insets converted at 360 dp (1 dp is 1.5 units) | ADR-0008 | Covered (Proposed) |
| TR-hud-008 | battle-hud.md | Every hit target is at least 48 dp, with no margin at 360 dp | ADR-0006 | Covered (Proposed) |
| TR-hud-009 | battle-hud.md | Prompt retirement flags survive a retry and reset when the app restarts | ADR-0002 | Covered (Proposed) |
| TR-hud-010 | battle-hud.md | The HUD is absent headless; nothing in the battle depends on it | ADR-0001 | Covered (Proposed) |
| TR-hud-011 | battle-hud.md | Modal screens use `focus_mode` NONE and top-band Controls use `mouse_filter` IGNORE (4.6 dual focus) | ADR-0006 | Covered (Proposed) |
| TR-hud-012 | battle-hud.md | Every HUD timer runs on one `advance` clock; the chip bar displays Tower's window | ADR-0003, ADR-0010 | Covered (Proposed) |
| TR-hud-013 | battle-hud.md | Frame time stays within 16.6 ms and memory within 256 MB on the low-end target phone (technical preferences) | ADR-0012 | Partial |
| TR-hud-014 | battle-hud.md | Frame order: HUD `advance`, then the frame's ticks, then view refresh, so a displayed call bonus equals the paid one (Rule 10) | ADR-0012, ADR-0003 | Covered (Proposed) |

## Partial Coverage Notes

- **TR-wave-004**: No ADR names the bad-speed guard. ADR-0003 gives `dt`; ADR-0009 gives the move step. Add the guard to ADR-0009 or a schema rule in ADR-0004.
- **TR-hud-006**: ADR-0014 leaves the game build hash and the launch ID NOT SOURCEABLE, and HUD Rule 19 needs both on every record.
- **TR-hud-013**: ADR-0012 measures 16.6 ms but no ADR sets a per-tick sim CPU budget. ADR-0003 allows 6 ticks a frame and points to ADR-0007 and ADR-0012; 6 x about 2 ms targeting leaves about 4.6 ms for the rest.

## Known Gaps

None. Every requirement has at least one ADR. The open items are the three partials above and the fact that no ADR is Accepted.

## New Requirements Registered by This Review

Each traces a GDD rule that an ADR already cites in its GDD Requirements Addressed table but that the baseline did not list.

- TR-input-008: `input-gesture-resolver.md`, adapter contract (Dependencies, Edge Cases). ADR-0006.
- TR-wave-010: `enemy-wave.md` Rule 14. ADR-0009.
- TR-wave-011: `enemy-wave.md`, field scale floor. ADR-0008.
- TR-hud-014: `battle-hud.md` Rule 10, frame order. ADR-0012 and ADR-0003.

## ID Changes

None. The registry was empty, so every provisional ID in `architecture.md` kept its number. Each is now permanent. ADRs that say "(provisional)" may drop the word on their next edit.

## Superseded Requirements

None. Three GDD sync edits on 2026-11-04 (commit 8905c49) came after `architecture.md` but did not change the intent of any baseline row.
