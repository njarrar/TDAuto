# ADR-0010: Tower System

## Status

Proposed

> TD-ADR: not run per ADR; batch review after all ADRs are written.
> Engine specialist validation: not run (no agents spawned for this batch).

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

lead-programmer (draft). Acceptance rests with the user or technical-director.

## Summary

Towers must run headless for bots yet need a real-time upgrade window that the stopped Build clock cannot give. This ADR splits the system into `TowerSim` (plain, headless, owns gold, slots and attack timers) and `TowerInput` (a thin shell node that registers hit targets and drives a pure `ChipWindow` from a millisecond feed), with result-coded commands shared by players and bots.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (sim) with an Input shell adapter |
| **Layer** | Feature |
| **Knowledge Risk** | HIGH for the version (VERSION.md). `TowerSim` and `ChipWindow` call no engine API. `TowerInput` touches only `Node` and the resolver's signals. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/architecture/architecture.md` (Engine Knowledge Gap Summary, Module Ownership, API Boundaries). The live 4.7.2 class reference was not fetched for this ADR. |
| **Post-Cutoff APIs Used** | None. A 4.7 rule applies to any base class with a typed-return method: an override inherits the return type and needs an explicit `return` (architecture.md). |
| **Verification Required** | NOT SOURCEABLE: the order of the input callback against the frame hook that feeds `ChipWindow` (ADR-0002, ADR-0003, ADR-0006). NOT SOURCEABLE: whether the frame hook runs before or after input in one frame. Both need a device run before this ADR is Accepted. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 Simulation and Shell Boundary; ADR-0005 Signal and Command Contracts; ADR-0006 Input Adapter and Resolver Integration; ADR-0007 Combat Data Model |
| **Enables** | Tower stories; ADR-0013 Content Test and Bot Harness (tower content rules, bots) |
| **Blocks** | Tower stories, in particular any TowerInput story |
| **Ordering Note** | `Battle.build` and `Battle.upgrade` are declared in ADR-0005's command set; this ADR owns the behaviour behind them. ADR-0003 owns the clamp on the real-time feed. |

## Context

### Problem Statement

A battle must run with no scene (Flow Rule 2), but the upgrade chip needs real time because the sim clock is stopped in Build. Two shell callers reach `TowerSim` (the HUD arc calls `build`, the chip calls `upgrade`). The TD review of architecture v1 accepted the split on conditions: TowerInput holds only registration and the chip disc, it has an equivalence test, and the two callers are documented. Tower's own GDD leaves three questions to this ADR: where TowerInput sits, the order of input against the real-time feed to `ChipWindow`, and re-entrancy.

### Current State

No code. `tower-system.md` fixes the rules:

- Two commands, `build(slot_index, tower_id)` and `upgrade(slot_index)`, return one result, checked in this order: `HALTED`, `BAD_SLOT`, `BAD_TOWER` (build only), `SLOT_OCCUPIED` or `NO_TOWER`, `MAX_LEVEL` (upgrade only), then the cost read, `HALTED` again, `NO_GOLD`, `OK`.
- IDs and levels are checked through the non-fatal `is_tower(id)` and `level_count(def_id)` before any accessor read. Cost is read at use time.
- On success, in one step: gold falls, the tower is made or raised, then `gold_changed` fires, then `tower_built` or `tower_upgraded`. A refusal changes nothing and emits nothing.
- Commands are live in every phase.
- Attack tick: count the timer down; read `range`; pick with Combat's `first_in` over `targets()` (a slow tower asks first among enemies with `speed_factor` 1); read every other stat before changing anything; set the timer to `to_ticks(attack_interval)`; call `report_attack`, then `deliver` per victim; a slow tower then calls `apply_slow`. A ready tower holds at 0. A new tower starts ready. An upgrade leaves the timer alone.
- Gold is one non-negative integer. Faucets: `starting_gold`, bounties, and the early-call bonus `to_ticks(seconds_left) div to_ticks(early_call_seconds_per_gold)`.
- The chip: a tap on the same tower commits when `200 <= elapsed < 1500` ms at release. Taps before 200 ms are ignored. It expires at 1500 ms. While open, TowerInput also registers a chip disc (radius 40, at the tower's x and y minus 76).

### Constraints

- Sim classes are `RefCounted` and load with no scene tree (ADR-0001).
- No listener inside a battle may call a command; a command during `in_tick()` is refused (the proposed default in architecture.md Data Flow section 3, for ADR-0005 to confirm).
- Stats are read through the catalogue accessor at the moment of use; nothing is cached.
- `TowerInput` changes state only through `upgrade`.

### Requirements

- TR-tower-001: TowerSim headless; TowerInput wrapper only; TowerInput changes state only through `upgrade`.
- TR-tower-002: ordered result codes; live in every phase; shared by players and bots.
- TR-tower-003: gold is one non-negative integer; the bonus formula.
- TR-tower-004: attack timers in integer ticks, ready-and-holding; a slow tower prefers an unslowed target.
- TR-tower-005: a pure `ChipWindow` fed real milliseconds, and a chip disc while open.

## Decision

### 1. The split

| Class | Kind | Built by | Holds |
|---|---|---|---|
| `TowerSim` | `RefCounted` | `BattleBuilder` | Gold, slot states, tower instances, attack timers, `build`, `upgrade`, `tick`, `on_enemy_killed`, `on_wave_called_early` |
| `ChipWindow` | `RefCounted` | `ShellBuilder` | Elapsed ms, the chip state, the 200 and 1500 limits |
| `TowerInput` | `Node` (thin adapter) | `ShellBuilder` | Hit-target registration for slots, towers and the chip disc; the call to `Battle.upgrade` on a commit; `slot_tapped`, `tower_inspected`, `chip_state()` |

`TowerInput` holds no gold rule, no cost rule and no result handling beyond one branch: on `NO_GOLD` the chip stays open and dimmed and the window does not restart; any other result closes it. That branch is the table in the GDD, and a test pins it.

### 2. Result enum

`TowerSim.Result { OK, HALTED, BAD_SLOT, BAD_TOWER, SLOT_OCCUPIED, NO_TOWER, MAX_LEVEL, NO_GOLD }` as in architecture.md. The order of checks is the GDD order above and is fixed by a table-driven test. `Battle.build` and `Battle.upgrade` forward to `TowerSim` and refuse while `in_tick()` is true, using the same enum value space (the refusal code for "in tick" is ADR-0005's to name; this ADR does not add a value).

### 3. Slot and gold state

- `_gold: int`, changed only by `on_enemy_killed`, `on_wave_called_early`, `build` and `upgrade`. `gold_changed` fires only when the value changes, so a bonus of 0 emits nothing.
- `_slots: Array[SlotState]`, sized from `StageRecord.slot_positions`. A slot index is the firing order.
- `slot_state(i)` returns a fresh `SlotState` copy. A copy stops a view from writing sim state. The cost is up to 5 small objects per frame on the starter stage (3 to 5 slots by layout rule L12); ADR-0012 measures it, and the fallback is a live object guarded by review.
- A `build` or `upgrade` commit does all state changes first, then emits `gold_changed`, then `tower_built` or `tower_upgraded`. A reader inside any handler sees the final state of both. This answers the GDD question about reads between `gold_changed` and `tower_built`: there is no half state to see.

### 4. Attack timers

Per-slot `cooldown_left` in ticks, counted down on every tick that runs (Intermission included, Build not, because Build runs no ticks). `to_ticks` comes from the injected `SimTime`. The tick order inside `TowerSim.tick()` is ascending slot index, with `halted()` checked after every accessor read and every signal. All reads for an attack are made before any state changes, so a bad read halts with nothing half done.

### 5. ChipWindow and its feed

```gdscript
class_name ChipWindow extends RefCounted
enum State { CLOSED, GUARD, OPEN, EXPIRED }   # GUARD: under 200 ms, taps ignored
func _init(guard_ms: int, expire_ms: int) -> void
func open() -> void
func close() -> void
func advance(ms: int) -> void       # real milliseconds since the last call
func elapsed() -> int
func state() -> int
```

- `guard_ms` is 200 and `expire_ms` is 1500. They are constructor arguments held in one constants file so tests can vary them. Whether they belong in the catalogue is not settled: the GDD text that classifies them was cut off in my read, so this is an open point for the review.
- The feed: the frame hook of `BattleWrapper` (ADR-0003) calls one shell-side `advance(ms)` per frame, with the real delta converted to whole milliseconds. That call runs `TowerInput.advance(ms)`, which calls `ChipWindow.advance(ms)`, then `HudLogic.advance(ms)`. One clock feeds both, so the chip bar and the window agree (TR-hud-012). ADR-0003 owns the 100 ms clamp the HUD uses; if it also applies here, a long frame shortens the window in wall time, and this ADR accepts that.
- Order of input against the feed: the window can only be read at the last `advance`. A release handled before this frame's `advance` sees `elapsed` from the previous frame. So a commit near 200 ms or 1500 ms can be off by one frame (16.7 ms at 60 fps). This ADR accepts that error and does not try to timestamp events. Whether the engine runs the input callback before the frame hook is NOT SOURCEABLE; the answer changes which side of a boundary the error falls on, not its size.
- While the phase is Paused, Won, Lost or Fatal, `TowerInput` closes the window on the `phase_changed` signal and ignores taps while `halted()`. A tap that resumes from Paused cannot commit.

### 6. Hit targets

`TowerInput` registers, through `InputResolver.register`, a slot disc (radius 36, from `input-gesture-resolver.md`) for each slot and a tower disc for built slots, and unregisters them itself. While the chip is open it registers the chip disc (the GDD says "TAP 300, radius 40"; I read 300 as the priority, to be confirmed against the Input GDD). It owns no other target. HUD arc discs belong to the HUD.

### 7. The two shell callers

`HudLogic` calls `Battle.build` (arc disc). `TowerInput` calls `Battle.upgrade` (chip commit). Both go through `Battle`, so both see the same refusals, and bots use the same two calls. They are not merged. A comment on each call site names the other.

### 8. Equivalence test

One integration test per command path: a fixed script run through the real `InputResolver` and `TowerInput` and the same script run as direct `Battle.build` and `Battle.upgrade` calls must end with identical snapshots (gold, slot states, damage counters). The snapshot seam is ADR-0001's. The test lives in `tests/integration/tower/`.

### Architecture Diagram

```
 HudLogic (arc disc) --Battle.build--------------+
 InputResolver -> TowerInput -> ChipWindow        v
        (commit)  --Battle.upgrade--------> Battle -> TowerSim (gold, slots, timers)
 shell advance(ms) -> TowerInput.advance -> ChipWindow.advance       |
 EnemyWave.targets (Callable) --> TowerSim.tick --> Combat.deliver / report_attack / apply_slow
```

### Key Interfaces

`TowerSim`, `SlotState` and the commands as in architecture.md API Boundaries, plus `ChipWindow` above and the `TowerInput` surface: signals `slot_tapped(slot_index)` and `tower_inspected(slot_index)`, method `chip_state() -> int`, and `advance(ms: int)`. `slot_tapped` and `tower_inspected` exist only in the shell and are not on the battle wiring test.

### Implementation Guidelines

- `TowerSim` must never reference a Node, the resolver or `ChipWindow`.
- `TowerInput` must never write sim state except through `Battle.upgrade`.
- A command must check `halted()` first, and again after the cost read.
- Cost and every stat must be read at use time and never cached from when an arc or chip opened.
- A refusal must change nothing and emit nothing.
- No handler of `gold_changed`, `tower_built` or `tower_upgraded` may call a command.
- Any base class with a typed-return method must give every override an explicit `return` (4.7 rule).
- `ChipWindow` tests must use explicit millisecond values, never real time.

## Alternatives Considered

### Alternative 1: One Node class that holds sim and input

- **Description**: A single `Tower` node with timers and registration.
- **Pros**: One class.
- **Cons**: Bots cannot build it headless. Gameplay branches would sit in a node.
- **Estimated Effort**: Lower at first.
- **Rejection Reason**: Violates ADR-0001 and Flow Rule 2.

### Alternative 2: Run the chip on sim ticks

- **Description**: Make the window a tick count.
- **Pros**: No second clock; deterministic.
- **Cons**: The clock is stopped in Build, so the chip would never expire there. The window is a human-timing guard against a bounce (Input Rule 8), so it must follow real time.
- **Estimated Effort**: Lower.
- **Rejection Reason**: Wrong time base for a guard against a physical bounce.

### Alternative 3: Time-stamp input events for the window

- **Description**: Use the event's own time for the 200 and 1500 limits.
- **Pros**: Removes the one-frame error.
- **Cons**: Needs an event timestamp API. NOT SOURCEABLE here.
- **Estimated Effort**: Medium.
- **Rejection Reason**: Cannot be sourced now; the one-frame error is small against a 200 ms guard. Revisit if the phone test shows boundary mis-fires.

### Alternative 4: Return the live `SlotState` from `slot_state()`

- **Description**: No copy.
- **Pros**: No allocation.
- **Cons**: A view can write sim state.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: Principle 5 (views read, never write). Kept as the fallback if ADR-0012 shows the copies cost too much.

## Consequences

### Positive

- Bots and players share two commands, so a bot result is a player result.
- `ChipWindow` and `TowerSim` are tested with no engine and no frames.
- No half state is visible to a listener.

### Negative

- A commit near a window boundary can be off by one frame.
- Two shell callers must be kept in step by hand and by the equivalence test.
- `slot_state()` allocates.

### Neutral

- `slot_tapped`, `tower_inspected` and `chip_state()` are invisible to headless wiring tests, so one story test with a fake resolver proves a tap reaches the arc (GDD rule 17).

## Risks

- The input and feed order differs from the assumption. Mitigation: a device run with a logged release time and a logged `elapsed` (the gesture log in ADR-0014).
- The chip disc priority reading is wrong. Mitigation: confirm against the Input GDD before the TowerInput story.
- Gold grows past `int` limits. Not reachable at starter values (upper bound 670 at most in the GDD).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| tower-system.md | TR-tower-001: TowerSim headless, TowerInput wrapper only, state change only through `upgrade` | The split table and the guideline on `TowerInput` writes |
| tower-system.md | TR-tower-002: ordered results, live in every phase, shared with bots | Result enum, fixed check order, both callers go through `Battle` |
| tower-system.md | TR-tower-003: one non-negative integer gold; bonus formula | `_gold: int`, change points listed, `gold_changed` only on change |
| tower-system.md | TR-tower-004: integer-tick timers, ready-and-holding, slow target preference | Section 4 |
| tower-system.md | TR-tower-005: pure `ChipWindow`, real ms, chip disc | Sections 5 and 6 |
| tower-system.md | "Becomes an ADR": where TowerInput sits, input against the feed, re-entrancy | Sections 1, 5 and 3 |

TR IDs are provisional until `/architecture-review` registers them. TR-tower-006 (signals) is ADR-0005's, and TR-tower-007 (content rules) is ADR-0013's.

## Performance Implications

- **CPU**: At most 5 slots, each with one `first_in` over at most 48 targets, so at most 240 compares a tick before splash. The 400-check worst case and its 2 ms bound belong to ADR-0007 and are unverified.
- **Memory**: 5 `SlotState` copies per frame read; no allocation in `tick()`.
- **Load Time**: None.
- **Network**: None.

## Migration Plan

New code. No migration.

**Rollback plan**: Merge `ChipWindow` into `TowerInput` (loses headless tests of the window) or replace the window with a tick count if the phone test shows the real-time feed is unreliable.

## Validation Criteria

- Table-driven test of the result order, including a halt during the cost read returning `HALTED` with gold short.
- `upgrade` twice with gold for one gives `OK` then `MAX_LEVEL`.
- A refusal changes nothing and emits nothing (recording fake).
- `ChipWindow` boundaries: 199 ignored, 200 commits, 1499 commits, 1500 expired.
- The equivalence test passes for a scripted build-and-upgrade sequence.
- Phone run: logged chip commits near the boundaries (ADR-0014).

## Related

- ADR-0001 Simulation and Shell Boundary; ADR-0005 Signal and Command Contracts; ADR-0006 Input Adapter and Resolver Integration; ADR-0007 Combat Data Model (dependencies)
- ADR-0003 Fixed Tick, Time and Determinism (the feed and the clamp); ADR-0012 (the `slot_state` copy cost); ADR-0013; ADR-0014
- `design/gdd/tower-system.md` (Core Rules 5 to 17, Formulas, Edge Cases)
