# ADR-0010: Sim/Input Split, Command Result Codes and Dev Telemetry

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05, against `architecture.md` v6, `tr-registry.yaml` v6 (123 entries), ADR-0001 to ADR-0009 (all Accepted) with their amendments, and probes T1 to T7 run on 4.7.2 headless (below).

## Decision Makers
Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`). Reviews still owed: godot-specialist and TD-ADR (the author could not start subagents). Acceptance: the user.

## Summary
Tower and Hero each need a headless half for bots and tests and a wrapper half for gestures, joined by commands with exact, ordered, side-effect-free refusals; three GDDs also need a debug-only log of human play. This ADR fixes what TowerSim, HeroSim, TowerInput and HeroInput own, every command's result enum (`OK = 0`, then `BUSY`, then the GDD's check order), Flow's command names (QQ-18), gold ownership, read-before-mutate, the bot path and equivalence tests, the run counters, the HUD read surface (B10), and one injectable JSONL sink that both RunLog and GestureLog write through.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2.stable.official.ed1daf0bf) |
| **Domain** | Core (simulation commands, GDScript data model); dev telemetry is Presentation |
| **Layer** | Core |
| **Knowledge Risk** | LOW for the sim (plain GDScript since 4.0). MEDIUM for the sink: `FileAccess.store_*` return `bool` since 4.4 (`breaking-changes.md`) |
| **References Consulted** | `VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `probe-results.md` (platform row, ADR-0002 E1 and KEY); no `modules/` file fits |
| **Post-Cutoff APIs Used** | `FileAccess.store_line() -> bool` (4.4). Nothing else |
| **Verification Required** | T1 to T7: verified 4.7.2 headless (below). Still open: `OS.is_debug_build()` false in a release export (needs export templates; joins ADR-0007 M4 at the first phone build) and the sink on Android `user://` (M2) |

| Probe | Result (verified 4.7.2 headless, Linux x86_64, editor binary) |
|---|---|
| T1 | `FileAccess.open(p, READ_WRITE)` on a missing file: `null`, `get_open_error()` 7 (`ERR_FILE_NOT_FOUND`). `open(p, WRITE)` creates it. `READ_WRITE` then `seek_end()` appends |
| T2 | `open("user://no_such_dir/x.jsonl", WRITE)`: `null`, error 7, and **no engine error or warning printed**, so a failure test passes gdUnit4's `push_error` reporting |
| T3 | `store_line()` and `store_string()` return `bool` (ClassDB return type 1); `true` on success; `false` on a `READ` handle, with no engine message. `flush()`, `close()`, `seek_end()` return `void` |
| T4 | `user://` writes headless (`~/.local/share/godot/app_userdata/<name>`); `OS.is_debug_build()` is `true` in the editor binary |
| T5 | `JSON.stringify(d)` sorts keys by default; `StringName` keys and values come out as plain strings; `1.0` as `1.0`, `3` as `3`, `0.1` as `0.1`; `PackedInt32Array` and read-only arrays as lists. `NAN` becomes `null` **with an engine warning**; `INF` becomes `1e99999`, which is not valid JSON |
| T6 | In a class with `enum E { OK, BUSY, ... }`, `E.OK == 0`, `E.keys()` keeps order, and bare `OK` still means the global `Error.OK` (0), not `E.OK`; a value falls through `if r:` as false |
| T7 | Desktop debug: `store_line` plus `flush` about 2.0 µs a line; open, `seek_end`, `store_line`, `close` about 16 µs |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009 (all Accepted 2026-11-04) |
| **Enables** | ADR-0011 (views draw from the B10 surface); GestureLog's sink (ADR-0008 Decision 8 waits on it) |
| **Blocks** | Every Tower and Hero story, the HUD arc, chip, Start/Call and result stories, GestureLog and RunLog. No story exists yet |
| **Ordering Note** | At acceptance, Migration Plan's sync items go out as dated amendments |

## Context

### Problem Statement
Bots and tests run with no scene or resolver (Flow Rule 2, Input Rule 11), but Tower's chip needs real time and Hero's aim a thumb. Tower and Hero split in two, joined by commands, and leave to this ADR: what each half owns, the result codes, Flow's command names (QQ-18), gesture-versus-command equivalence (TR-hero-012), the counters, and the debug log three GDDs need at first playable (HUD Rule 19, Input Rule 13).

### Constraints
- ADR-0004, ADR-0006: the command shell `if in_tick(): return refusal; enter(); var r := _body(...); exit(); return r`; commands only between ticks; commit, then emit.
- ADR-0005: reused `ReadContext`s; commands read before any change; `halted()` after every read.
- ADR-0006 Decision 3 and lint L-SIG-5: view listeners never command or write; RunLog and ResultScreen name no sim member or class.
- ADR-0009 Decision 8: Flow, Tower and Hero bookkeeping and all `halted()` calls share 0.2 ms of the 2.0 ms tick.
- `BattleBuilder.build(catalogue, stage_id, rng_seed, fatal_handler)` is fixed (ADR-0001). Sim folders read no `OS`, `Time` or `Engine` (L-TIME-1).

### Requirements
The TRs in GDD Requirements Addressed; text in `tr-registry.yaml`.

## Decision

### 1. The split
All four extend `RefCounted`. The Builder makes the Sims, also headless; only the wrapper makes the Inputs, as plain objects, so tests can build them with a real resolver and no scene.

| Class (file) | Owns | Changes the battle by |
|---|---|---|
| `TowerSim` (`src/feature/tower/tower_sim.gd`) | Gold, slots, towers, per-tower `cooldown_left`, one `ReadContext` per built slot plus one scratch, one reused `DamageEvent`, one `SlotState` per slot, `towers_built`, `slows_applied` | Its own commands and tick |
| `TowerInput` (`src/presentation/tower/tower_input.gd`) | Slot and tower discs, the chip disc, its `ChipWindow`, `chip_state()` and one reused `ChipState`, signals `slot_tapped(slot_index: int)` and `tower_inspected(slot_index: int)` | `upgrade()` only |
| `HeroSim` (`src/feature/hero/hero_sim.gd`) | Position, pin target, pin and burst state, walk, attack, cooldown and telegraph timers, `aim_point` once committed, two `ReadContext`s, one `DamageEvent`, one `HeroCounters` | Its own commands and tick |
| `HeroInput` (`src/presentation/hero/hero_input.gd`) | Hero, button and sink discs; aim state (Idle, Cancelling, Live), aim point and its re-clamp, cancel hysteresis, the pin ghost through `PinGeometry.clamp`, previews, `cooldown_digit()`, `update()` | `pin()` and `burst()` only |

- `ChipWindow` (`src/presentation/tower/chip_window.gd`) is TowerInput's (settled 2026-11-04), fed by `tower_input.advance(ms)` in frame step 1.
- `HudLogic` issues `build()` (from the arc), `start_wave()` and `call_early()`. No other `src/` file calls a command (lint L-CMD-1, Migration item 4).
- `burst_button_centre()` is the HUD's. The wrapper builds the HUD first and passes the `Vector2` to `HeroInput.setup()`, which reads it once; tests pass any point (TR-hero-015).
- `PinGeometry` (`src/feature/hero/pin_geometry.gd`) stays pure and is shared: HeroSim's `pin()` validates with `is_valid`, and HeroInput and bots clamp with `clamp`.

### 2. Result enums
Each command has its own enum on its class. Every enum starts `OK = 0`, then `BUSY = 1`, then the GDD's check order. `BUSY` replaces the name `ERR_COMMAND_IN_TICK` for the result: the command was called inside a tick or inside another command. The dev-error text stays `ERR_COMMAND_IN_TICK: <Class>.<command>`, as ADR-0004 and ADR-0006 name it.

```gdscript
# TowerSim (Tower Rule 5)
enum BuildResult   { OK, BUSY, HALTED, BAD_SLOT, BAD_TOWER, SLOT_OCCUPIED, NO_GOLD }
enum UpgradeResult { OK, BUSY, HALTED, BAD_SLOT, NO_TOWER, MAX_LEVEL, NO_GOLD }
# HeroSim (Hero Rules 2, 6)
enum PinResult     { OK, BUSY, HALTED, BAD_POSITION, OUT_OF_BOUNDS, BUTTON_ZONE }
enum BurstResult   { OK, BUSY, HALTED, BUILD_PHASE, NOT_PINNED, NOT_READY, BAD_POSITION, OFF_FIELD, OUT_OF_REACH }
# Flow (QQ-18; Flow Rules 6, 9, Formulas, Edge Cases)
enum StartResult   { OK, BUSY, HALTED, NOT_BUILD }
enum CallResult    { OK, BUSY, HALTED, NOT_INTERMISSION, NO_TIME_LEFT }
```
- **Order is the order of checks**, and the first failing check wins. `HALTED` also follows each accessor read (Decision 3), so it can come after a later check passed.
- **Compare explicitly**: `if r == TowerSim.BuildResult.OK`. Never `if r:` (`OK` is 0, falsy, T6) and never bare `OK` (that is the global `Error.OK`, T6; it equals 0 only by chance). Lint L-CMD-2.
- **Flow's `HALTED`** is Flow's own phase in WON, LOST or FATAL. Flow takes no `halted()`: the battle latch moves Flow to FATAL in `_on_latched` before any command can run. `NOT_BUILD` and `NOT_INTERMISSION` cover PAUSED too. `NO_TIME_LEFT` is a call in Intermission at `intermission_left == 0` ("a call at 0 is ignored with no signal").
- `pause()` and `resume()` stay `void` (ADR-0006 Decision 7).
- **Callers**: HudLogic and TowerInput keep their UI open on `NO_GOLD` and close on anything else, HudLogic reporting a dev error for codes other than `HALTED` (HUD Rule 7, Tower Rule 8); HeroInput reports anything but `OK` or `HALTED` (Hero Rule 13); bots record every result.

### 3. Commands: checks, reads, commit
Each public command is ADR-0006 Decision 7's shell around a private `_<name>_body()`. On `in_tick()` it reports `ERR_COMMAND_IN_TICK` once and returns `BUSY`.

| Command | Checks in order (after BUSY) | Accessor reads, each followed by `if halted(): return HALTED` | Commit, then emit |
|---|---|---|---|
| `build(slot_index, tower_id)` | `halted()`; `0 <= slot_index < slot count`; `is_tower(tower_id)`; slot empty | scratch `(tower_id, 1)`: `COST`; then `gold < cost` is `NO_GOLD` | `gold -= cost`; slot holds `tower_id` at level 1, `cooldown_left` 0, its own `ReadContext`; `towers_built += 1`; emit `gold_changed(gold)`, `tower_built(slot_index, tower_id)` |
| `upgrade(slot_index)` | `halted()`; slot index; slot built; `level < level_count(def_id)` | scratch `(def_id, level + 1)`: `COST`; then `NO_GOLD` | `gold -= cost`; slot level and its context's `level` rise; timer unchanged (Rule 12); emit `gold_changed`, `tower_upgraded(slot_index, level)` |
| `pin(pos)` | `halted()`; `pos.x`, `pos.y` finite; `PinGeometry.is_valid(pos, pin_rect, active shapes)` gives `OUT_OF_BOUNDS` or `BUTTON_ZONE` | Hero context: `WALK_SPEED` | `repins += 1` if pinned before and `pos` differs from `position()`; target, `walk_left` (walk_ticks formula), state Walking or Pinned; emit `hero_pinned(pos)` |
| `burst(aim)` | `halted()`; not `in_build()`; pinned once; Ready; finite; inside 0..540 and 0..960 inclusive | Burst context: `REACH`, then the squared reach test (`OUT_OF_REACH`); then `TELEGRAPH_DURATION` | `aim_point = aim`; `telegraph_left = max(1, to_ticks(telegraph_duration))`; Telegraphing; emit `burst_started(aim, telegraph_left)` |
| `start_wave()` | phase not terminal; phase is BUILD | none | phase WAVE; injected `start_next_wave()`; emit `phase_changed(WAVE)` |
| `call_early()` | phase not terminal; INTERMISSION; `intermission_left > 0` | none | `seconds_left = intermission_left * dt`; `intermission_left = 0`; phase WAVE; `start_next_wave()`; emit `wave_called_early(seconds_left)`, then `phase_changed(WAVE)` |

- **Read before mutate, every command (TR-tower-006 shared part).** Every accessor read a command needs happens before its first write, through the owner's scratch or entity context, and is followed by a `halted()` check. A bad read latches through the accessor's `fatal`, the command returns `HALTED`, and gold, slots and hero state are unchanged (Tower Edge Cases). Non-fatal lookups (`is_tower`, `level_count`) run before any read, so a bot's bad ID returns a refusal, never a fatal.
- **The guard covers listeners**: a handler that commands gets `BUSY` (ADR-0006 Decision 7). TowerSim's `_on_wave_called_early` is no command, so it pays inside Flow's guard.
- Flow starts a wave through `EnemyWave.start_next_wave`, injected by the Builder as a method Callable beside `wave_index()`, since Core cannot name Feature (sync item for B9).

### 4. Gold (TR-tower-008, TR-tower-009)
- One `int` `_gold`, never negative, written only by TowerSim: `_init` (`starting_gold`, read directly from Stage), `_on_enemy_killed(bounty)`, `_on_wave_called_early(seconds_left)`, `build`, `upgrade`. Each handler and command checks `halted()` first, so gold freezes once halted. `gold_changed(gold)` fires only on a change.
- **The bonus is integer tick maths**: `call_bonus(ticks_left: int) -> int` returns `ticks_left / to_ticks(early_call_seconds_per_gold)` (whole-number division; the rate read directly from Stage, at least one tick by the Data validator). The handler pays `call_bonus(to_ticks(seconds_left))`. The HUD shows "Call +N" from the same pure `call_bonus(flow.intermission_left)`, so shown equals paid (ADR-0004 Decision 4). No burst state is read (Flow Rule 9).

### 5. Run counters (TR-hero-009)
- **HeroSim** owns one `HeroCounters` (`src/feature/hero/hero_counters.gd`): `ever_pinned: bool`, `repins`, `bursts_fired`, `bursts_hit_0`, `bursts_hit_3`, `bursts_hit_5`, `burst_victims`, `burst_kills` (`int`), `kills_per_burst: Array[int]` (one entry per release, 0 included), `kills_on_hit_3: Array[int]`. Definitions are Hero Rule 16. `pin()` sets `ever_pinned` and `repins` in its commit; the release sets the rest after its delivers (Hero step 7). `counters()` returns the same instance, read-only by contract, never kept past the reader's slot.
- **TowerSim**: `towers_built() -> int`, `slows_applied() -> int` (every `apply_slow` call, Tower Rule 17).
- **The snapshot** (ADR-0006 Decision 9) gains every `HeroCounters` field and `towers_built`, as plain copies, each array `make_read_only()`. HUD Rule 16's next-try line reads `ever_pinned`, `towers_built` and `bursts_fired` there. The cost sits in the 0.2 ms bookkeeping share.

### 6. HUD read surface (B10; TR-hud-010 shared part)
Views read only these side-effect-free queries, in frame step 3 or a VIEW handler.

| Owner | Reads |
|---|---|
| Flow | `phase()`, `lives()`, `in_build()`, `intermission_left` (read-only by contract), `result()` |
| TowerSim | `gold()`, `slot_count()`, `slot_state(slot_index) -> SlotState` (`tower_id: StringName`, `&""` when empty; `level: int`, 0 when empty; `cooldown_left: int`), `call_bonus(ticks_left)`, `towers_built()`, `slows_applied()` |
| TowerInput | `chip_state() -> ChipState` (`open: bool`, `slot_index: int`, `elapsed_ms: int`, `level: int`); signals `slot_tapped`, `tower_inspected` |
| HeroSim | `position()`, `pin_target()`, `pin_state()`, `burst_state()`, `cooldown_left()`, `aim_point()` (committed, while Telegraphing), `counters()` |
| HeroInput | `aim_state()`, `aim_point()` (the live preview), `cooldown_digit()` |
| EnemyWave | `wave_index()`, `got_through_by_type()`, `roster()`, `targets()` (ADR-0009) |
| Combat | `hp_left(enemy)`, `is_dead(enemy)` for the kill preview (ADR-0009) |

`SlotState` and `ChipState` are reused, like `roster()`; never kept past the slot. Costs, ranges and Burst `cooldown` come through the accessor in frame step 3 (ADR-0005). ResultScreen and RunLog read only the snapshot, which carries `hero_share`, so no view reads `Combat.hero_share()`.

### 7. Bots and the equivalence tests (TR-hero-012; TR-input-014 shared part)
- **Bots call commands directly.** A bot builds with `BattleBuilder.build`, then plays a **command script**: `(tick_index, command)` pairs, each applied after `tick_index` ticks and before the next (ADR-0004 Decision 6), then `battle.tick(battle.tick_seconds())`. No resolver, HeroInput or TowerInput; results come from queries and `take_result_snapshot()`. Bots live in `tests/helpers/bots/` (no `class_name`, ADR-0007), called by integration tests, benches or a `tools/` SceneTree script.
- **Resolver equivalence** (`tests/integration/hero/hero_equivalence_test.gd`, Hero AC 27): run A drives a real `InputResolver`, `HeroInput` and `TowerInput` from a tick-indexed gesture script (press, move, release at field positions, applied between ticks, `hero_input.update()` before each tick, no adapter, no scene). Run B plays the matching command script on a second battle from the same `(catalogue, stage_id, rng_seed)`. A command spy on both records identical `pin`, `burst`, `build` and `upgrade` calls with identical results, and `battle_state.digest()` (ADR-0007) plus `counters()` match after every tick. The script holds at least Hero AC 27's six gestures and one chip upgrade.
- **Never pinned equals absent** (Hero AC 28): building without HeroSim would need a new Builder flag, so the test proves absence. On a towers-only script to WON or LOST, each tick, a never-pinned HeroSim makes no read with its contexts, no Combat call of kind HERO or BURST and no emit, and no field changes. `Battle.tick` touches Hero only through `hero_sim.tick()`, so that equals absence.

### 8. Dev telemetry: one sink, two logs (TR-hud-013; TR-input-015 shared part; Data Flow 9)
**Debug builds only.** The wrapper builds the sinks, `RunMeasures`, `RunLog` and `GestureLog` only when `OS.is_debug_build()` is true, so release builds write nothing. The files ship; no export filter.

**The sink.** `class_name JsonlFileSink extends RefCounted`, `src/presentation/dev/jsonl_file_sink.gd`, the only `FileAccess` user outside the catalogue (lint L-DEV-1).
```gdscript
func _init(path: String, max_bytes: int = 8 * 1024 * 1024) -> void
## Appends one line. False on a release build, a failed open, a failed store or a full file.
## Never reports, never halts; the caller reports its first false once.
func append_line(line: String) -> bool
func close() -> void   # the wrapper calls it at teardown
```
- Opens on the first line: `READ_WRITE` plus `seek_end()` if the file exists, else `WRITE` (T1). Keeps the handle; each line is `store_line` then `flush()`, so a crash loses nothing written (T3, T7). A failed open is remembered; later calls return `false`.
- One sink each for `user://run_log.jsonl` and `user://gesture_log.jsonl`. Tests inject a recording fake, or a real sink on a missing directory (T2; integration only, L-TEST-2).
- **Never fatal.** RunLog and GestureLog take `sink.append_line` as a method Callable, report the first `false` once to `dev_error` and go on (ADR-0008 Decision 8).

**Line format.** One JSON object per line from `JSON.stringify(dict)` (keys sorted, T5), each with `v: 1`, `kind`, `launch_id` and `build`. Writers replace a non-finite float with `null` before stringify, since `NAN` raises an engine warning and `INF` writes invalid JSON (T5). `launch_id` and `build` are `String`s AppRoot passes to the wrapper (open item 1).

**RunMeasures** (`src/presentation/dev/run_measures.gd`) names sims so RunLog need not: a view-only listener through `view_wiring` (a WIRING signal may take view listeners, ADR-0006 Decision 3). It owns what the sim does not:
- the real seconds to the first `hero_pinned`, `tower_built` and `burst_started`, from an injected `now_ms` (`Time.get_ticks_msec` in the wrapper, a fake in tests);
- per call, from `wave_called_early(seconds_left)`: `seconds_left`, HeroSim's `burst_state()` at that moment (between ticks, so what the player saw), and `flow.lives()`; the call record closes, with lives lost, at the next `phase_changed` to INTERMISSION or an outcome;
- `best_victims` per release: in its `attack_fired` handler for kind BURST, the largest count of `targets()` within the burst `radius` of any one target, through `Combat.all_in_radius`. It keeps no list. It is O(n²) inside a tick, so it lives here, never in HeroSim: release ticks never pay it.

**RunLog** (`src/presentation/dev/run_log.gd`, names no sim, L-SIG-5): `write_call(record: Dictionary)` when RunMeasures closes a call; `write_attempt(snapshot: ResultSnapshot, measures: Dictionary)` once, with the frame step 3 snapshot on WON or LOST. The attempt line holds HUD Rule 19's fields: towers built, lives, last wave, damage by source and kind, `slows_applied`, the Hero counters, `kills_per_burst`, `best_victims`, got through by type, and the three real times. A quit leaves no attempt line; FATAL takes no snapshot.

**GestureLog** (ADR-0008 Decision 8) is unchanged, except that its `chip_state` Callable is `TowerInput.chip_state`, and its `append_line` is the gesture sink's.

### Architecture Diagram
```
Bots ─► command script ─► flow / tower_sim / hero_sim commands ◄─ HudLogic, TowerInput, HeroInput
command: BUSY? : enter ─► checks ─► reads + halted() ─► commit ─► emit ─► exit
Debug only, through view_wiring: sim signals, queries ─► RunMeasures ─► RunLog ◄─ ResultSnapshot
  resolver signals, last_trace(), chip_state() ─► GestureLog
  RunLog, GestureLog ─► append_line ─► JsonlFileSink (user://run_log.jsonl, user://gesture_log.jsonl)
```

### Key Interfaces
Decision 2 gives the enums, Decision 6 the queries, ADR-0006 the signals. New signatures:
```gdscript
# TowerSim
func build(slot_index: int, tower_id: StringName) -> BuildResult
func upgrade(slot_index: int) -> UpgradeResult
func slot_state(slot_index: int) -> SlotState      # reused; empty state for a bad index
func call_bonus(ticks_left: int) -> int             # pure
# HeroSim; enum PinState { UNPINNED, WALKING, PINNED }, enum BurstState { READY, TELEGRAPHING, COOLING }
func pin(pos: Vector2) -> PinResult
func burst(aim: Vector2) -> BurstResult
func counters() -> HeroCounters                     # reused
# Flow (B5 additions)
func start_wave() -> StartResult
func call_early() -> CallResult
# TowerInput
func setup(resolver: InputResolver, tower_sim: TowerSim, stats: StatAccessor, halted: Callable, dev_error: Callable) -> void
func advance(ms: float) -> void                     # frame step 1; feeds ChipWindow
func chip_state() -> ChipState
# HeroInput; enum AimState { IDLE, CANCELLING, LIVE }
func setup(resolver: InputResolver, hero_sim: HeroSim, combat: Combat, stats: StatAccessor, burst_id: StringName,
		stage: StageRecord, left_handed: bool, button_centre: Vector2, in_build: Callable, halted: Callable, dev_error: Callable) -> void
func update() -> void                               # frame step 1
```
Names a GDD does not fix are proposed.

### Implementation Guidelines
1. Every command must have the ADR-0006 shell and must return `BUSY` when `in_tick()` is true, reporting `ERR_COMMAND_IN_TICK: <Class>.<command>`.
2. Every result enum must start `OK, BUSY`, then follow the GDD's check order. A new refusal must go in its GDD order, never at the end by default.
3. Callers must compare a result to its qualified `OK` value; never `if r:` and never bare `OK` (L-CMD-2).
4. A command must make every non-fatal lookup, then every accessor read, each read followed by `if halted(): return HALTED`, before its first write.
5. A refusal must change no field, counter or registry and must emit nothing.
6. Only TowerSim writes gold; every gold writer must check `halted()` first.
7. Only HudLogic, TowerInput and HeroInput may call commands in `src/`, each only its own (L-CMD-1). Bots and tests call them freely.
8. TowerInput and HeroInput must never write a sim field or keep a query result past its slot. TowerInput uses only the non-fatal `level_count`. HeroInput reads Burst `reach`, `radius` and `damage` (aim clamp, kill preview) only in `update()` (frame step 1, outside any tick or handler), through its own `ReadContext`, `halted()` after each: an ADR-0005 amendment (Migration item 2).
9. Counters commit before any emit of their action; views read only the B10 surface (Decision 6).
10. Only `jsonl_file_sink.gd` and `catalogue.gd` may name `FileAccess` (L-DEV-1). Nothing outside `src/presentation/dev/` may name `JsonlFileSink`, `RunMeasures`, `RunLog` or `GestureLog`, except the wrapper.
11. The wrapper must build every dev telemetry object only when `OS.is_debug_build()` is true; telemetry must never call a command or write sim state.
12. A sink failure must never reach `fatal`, `halted()` or a result.
13. Writers must turn non-finite floats into `null` before `JSON.stringify`.

## Alternatives Considered

### Alternative 1: One Tower and one Hero object, input optional
- **Description**: one class each, input idle headless. **Pros**: fewer classes. **Cons**: no test can prove input acts only through commands.
- **Rejection Reason**: both GDDs split on purpose; TR-tower-001 and TR-hero-001 require it.

### Alternative 2: A command queue drained by `Battle.tick`
- **Description**: inputs post commands; the tick applies them first. **Pros**: one place sees every command. **Cons**: results arrive a tick late, so "Need N gold" and the chip's `NO_GOLD` cannot answer their tap.
- **Rejection Reason**: ADR-0004 Decision 4 already rejected the S1 queue; the HUD rules need synchronous results.

### Alternative 3: One shared result enum
- **Description**: one `CommandResult` with every code. **Pros**: one type. **Cons**: cannot list each command's codes in its own check order; callers could test codes a command never returns.
- **Rejection Reason**: the order is part of the contract (TR-tower-002, TR-hero-002).

### Alternative 4: RunLog listens to the sims itself
- **Description**: one class hears sim signals and reads queries. **Pros**: one file. **Cons**: breaks the Accepted lint L-SIG-5, so log values could drift from the screen's.
- **Rejection Reason**: a sim-blind writer plus RunMeasures keeps the lint.

### Alternative 5: Buffered sink flushed once per frame
- **Description**: `append_line` queues; the wrapper flushes in frame step 3. **Pros**: no file call in a handler or tick. **Cons**: `append_line` could not return the real `bool` ADR-0008 fixed; a crash loses the frame's lines.
- **Rejection Reason**: direct writes cost about 2 µs a line (T7), in debug builds only.

## Consequences

### Positive
- Every refusal is named, ordered and testable from a fake; a bot sees the codes a thumb does, and the equivalence tests make bot balance speak for real play.
- Release builds carry no telemetry, and no log failure can touch a battle.

### Negative
- Four classes where a naive design has two, plus three dev classes; `BUSY` and the read-time `HALTED` add a branch to every caller.
- `best_victims` is O(n²) inside debug ticks, so debug burst-release ticks run long.

## Risks
- **A new refusal appended at the end**: Guideline 2 and the paired-fault tests catch it.
- **Equivalence flakes on float drift**: both runs share build, OS and CPU (ADR-0004 Decision 9) and compare digests.
- **Android `user://` write fails**: the first `false` reports once; M2 checks a line on the device.
- **Unbounded files**: the 8 MiB cap stops writing and reports once.
- **Reviews owed**: godot-specialist and TD-ADR have not seen this draft.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| tower-system.md | TR-tower-001: TowerSim headless; TowerInput changes state only through `upgrade` | Decision 1, Guideline 7, L-CMD-1 |
| tower-system.md | TR-tower-002: `build`, `upgrade` only mutation API, typed result in check order | Decisions 2, 3 |
| tower-system.md | TR-tower-006 (shared): stats read before any mutation | Decision 3, Guideline 4. ADR-0001 keeps the `halted()` check |
| tower-system.md | TR-tower-008: gold owned by TowerSim, freezes once halted | Decision 4 |
| tower-system.md | TR-tower-009: early-call bonus integer tick maths | Decision 4, `call_bonus` |
| hero-system.md | TR-hero-001: HeroSim and HeroInput; input only through `pin`, `burst` | Decision 1, Guideline 7 |
| hero-system.md | TR-hero-002: ordered enums, state before geometry, refusal mutates nothing | Decisions 2, 3, Guideline 5 |
| hero-system.md | TR-hero-009: read-only queries and per-run counters | Decisions 5, 6 |
| hero-system.md | TR-hero-012: resolver and direct scripts tick-identical; never-pinned equals absent | Decision 7 |
| hero-system.md | TR-hero-015: `burst_button_centre()` owned by HUD, read once, injectable | Decision 1 |
| battle-hud.md | TR-hud-010 (shared): view-only query surface | Decision 6. ADR-0006 keeps the signals |
| battle-hud.md | TR-hud-013: debug run log, injectable sink, non-fatal failure, no release writes | Decision 8 |
| input-gesture-resolver.md | TR-input-014 (shared): bots call commands, one equivalence test | Decision 7. ADR-0007 keeps fakes and logs |
| input-gesture-resolver.md | TR-input-015 (shared): the gesture log's sink | Decision 8. ADR-0008 keeps the trace and harness |
| game-state-stage-flow.md | QQ-18: Flow command names and results | Decision 2 |

## Performance Implications
- **CPU**: commands sit in the 0.5 ms input slice (a few checks, at most two reads); tick-side counters in ADR-0009's 0.2 ms bookkeeping share; debug adds RunMeasures and about 2 µs a line, release nothing.
- **Memory**: a few reused objects and two arrays of about 11 entries. **Load Time**, **Network**: none.

## Migration Plan
No code exists. Sync items, none made here:
1. **`architecture.md`**: B5 takes Decision 2's Flow enums and resolves QQ-18; B8 gains `BUSY`, `slot_state(slot_index) -> SlotState`, `slot_count`, `call_bonus`, counters; B9 gains `start_next_wave`; B10 takes Decision 6 (drops `Combat.hero_share()`); the RunLog / GestureLog row and Data Flow 9 name RunMeasures and `JsonlFileSink`; B0's `ResultSnapshot` row lists the new fields; Required ADRs marks ADR-0010 written.
2. **ADR-0004** Decision 6 and **ADR-0006** Decision 7: the refusal value is `BUSY`; the report text is unchanged. ADR-0006 Decision 9 lists Decision 5's snapshot fields. **ADR-0005** Decision 5 and L-STAT-4 add HeroInput as a reader in `update()` (Guideline 8).
3. **ADR-0008** Decision 8: `chip_state` is TowerInput's read, not TowerSim's (settled 2026-11-04).
4. **ADR-0007** lint rows: L-CMD-1 (command calls in `src/` only from their owners' files), L-CMD-2 (`if`, `not`, `and`, `or` directly before a command call; bare `OK` compared to a result), L-DEV-1 (`FileAccess` only in `catalogue.gd` and `jsonl_file_sink.gd`); `scopes.gd` names `run_measures.gd`; L-STAT-4 adds `hero_input.gd`.
5. **GDDs** (game-designer, user sign-off): Tower Rule 5's table and Hero Rules 2 and 6 gain `BUSY` first and a read-time `HALTED`; Hero's `pin` reads `walk_speed` before its commit; Game State names `start_wave`, `call_early` and their results; HUD Rule 19 names RunMeasures and RunLog; Tower Rule 17's `slot_state` returns a reused `SlotState`.
6. **`docs/registry/architecture.yaml`**: Proposed entries appended (gold, run counters, command results, sink, telemetry ban).

## Validation Criteria
- **V1 Paired faults** (unit): co-occurring faults return the earlier code, each code alone too; `BUSY` from a tick, a sim handler and another command; nothing changed or emitted on a refusal.
- **V2 Read before mutate** (spy accessor `fire_fatal_on(1)`): `build`, `upgrade`, `pin`, `burst` return `HALTED` with nothing changed or emitted.
- **V3 Gold**: bonus 8, 7, 0 at 900, 863, 107 ticks and 1.8 s (Tower Formulas); `call_bonus` equals the paid bonus; no `gold_changed` at 0; frozen once halted.
- **V4 Flow**: Game State AC 1, 3, 4, 8, 15 with the new results. **V5 Counters**: Hero AC 16; snapshot copies read-only.
- **V6 Equivalence**, **V7 Never pinned** (integration): Decision 7.
- **V8 Sink** (integration): appends, creates; a missing directory gives `false`, no engine message, one caller dev error; the cap gives `false`.
- **V9 Telemetry** (fakes): one attempt line per WON or LOST, one call line per real call; `NAN` as `null`; digest identical with telemetry removed (TR-hud-004).
- **V10 Release** (export templates): no telemetry object, no file (joins ADR-0007 M4). Lints L-CMD-1, L-CMD-2, L-DEV-1 each fail a sample.

## Related
- ADR Dependencies lists the ADRs. Supplies ADR-0008 Decision 8's sink; ADR-0011 draws from Decision 6.
- GDDs: those in GDD Requirements Addressed.
- Open items for the user: the source of `launch_id` and the build hash (proposed: AppRoot makes `launch_id` once per launch; build from `application/config/version`), the 8 MiB cap, `best_victims` in debug ticks only, never-pinned proved by isolation.
