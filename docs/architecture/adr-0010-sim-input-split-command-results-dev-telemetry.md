# ADR-0010: Sim/Input Split, Command Result Codes and Dev Telemetry

## Status
Accepted

## Date
2026-11-05

## Last Verified
2026-11-05, against `architecture.md` v7, `tr-registry.yaml` v6 (123 entries), ADR-0001 to ADR-0009 (all Accepted) with their amendments, and the 4.7.2 headless probes below.

## Decision Makers
- Accepted: 2026-11-05 by the user (njarrar), with its amendments to ADR-0004 to ADR-0008, the Hero AC 28 and HUD Rule 19 GDD changes, and the 8 MiB dev log cap
Author: `/architecture-decision`, autonomous mode (decisions in `production/session-logs/decision-log.md`). Reviews: godot-specialist APPROVE, TD-ADR CONCERNS, resolved below. Acceptance: the user.

## Summary
Tower and Hero need a headless half and a gesture half, joined by commands with exact, ordered refusals; three GDDs need a debug-only play log. This ADR fixes what TowerSim, HeroSim, TowerInput and HeroInput own, every command's result enum (`OK = 0`, then `BUSY`, then the GDD's check order), Flow's command names (QQ-18), gold ownership, read-before-mutate, the bot path and equivalence tests, run counters, the HUD read surface (B10), and one JSONL sink that RunLog and GestureLog share.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2.stable.official.ed1daf0bf) |
| **Domain** | Core (simulation commands, GDScript data model); dev telemetry is Presentation |
| **Layer** | Core |
| **Knowledge Risk** | LOW for the sim (plain GDScript since 4.0). MEDIUM for the sink: `FileAccess.store_*` return `bool` since 4.4 (`breaking-changes.md`) |
| **References Consulted** | `VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `probe-results.md` (platform row, ADR-0002 E1, KEY) |
| **Post-Cutoff APIs Used** | `FileAccess.store_line() -> bool` (4.4). Also used: `FileAccess.get_length()`, static `FileAccess.get_size()`, `Crypto.generate_random_bytes()`, `Time.get_unix_time_from_system()` |
| **Verification Required** | All probes below verified 4.7.2 headless. Still open: release-export `OS.is_debug_build()` false (ADR-0007 M4) and Android `user://` writes (M2) |

| Probe | Result (verified 4.7.2 headless, Linux, editor binary; T by the author, R and K by godot-specialist) |
|---|---|
| T1, R4 | `open(p, READ_WRITE)` on a missing file: `null`, error 7. `WRITE` creates it. `READ_WRITE` plus `seek_end()` appends. `get_length()` tracks appends; static `get_size()` exists; dropping a handle without `close()` loses no flushed line |
| T2, T3 | `open()` in a missing directory: `null`, error 7, **no engine message**. `store_line()` returns `bool`, `false` on a `READ` handle, silently; `flush()`, `close()` return `void` |
| T4, R7 | `user://` writes headless. In the editor binary `OS.is_debug_build()` and `has_feature("debug")` are true, `template_release` false |
| T5, R8 | `JSON.stringify` sorts keys; `StringName` becomes a string; default precision keeps telemetry values. `NAN` becomes `null` with an engine warning; `INF`, even inside a nested `Array`, writes `1e99999`, invalid JSON |
| T6, R1, R9 | `enum E { OK, BUSY }`: `E.OK == 0`, qualified compare works. Bare `OK` in the class is `Error.OK` (named enum members are not class constants). Returning bare `OK` from a `-> BuildResult` function is a parse error; a caller's `r == OK` parses silently and is true |
| T7, K | `store_line` plus `flush`: about 2 µs a line, desktop. A flushed line survives SIGKILL; an unflushed one is lost |
| R2 | `call_bonus` as instance or static method both work; `int / int` truncates |
| R3 | A sink held only by a method `Callable` frees at once and the `Callable` goes invalid |
| R5, R6 | `Time.get_unix_time_from_system()`, `Crypto.generate_random_bytes()` work headless; `application/config/version` is `""` by default |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009 (all Accepted 2026-11-04) |
| **Enables** | ADR-0011 (views draw from B10); GestureLog's sink (ADR-0008 Decision 8) |
| **Blocks** | Every Tower and Hero story, the HUD arc, chip, Start/Call and result stories, GestureLog and RunLog. No story exists yet |
| **Ordering Note** | At acceptance, the Migration Plan's sync items go out as dated amendments |

## Context

### Problem Statement
Bots run with no scene or resolver (Flow Rule 2, Input Rule 11), but the chip needs real time and the aim a thumb. The GDDs split Tower and Hero and leave to this ADR the halves' ownership, result codes, QQ-18, equivalence (TR-hero-012), counters and the debug log (HUD Rule 19, Input Rule 13).

### Constraints
- ADR-0004, ADR-0006: the command shell; commands only between ticks; commit, then emit. ADR-0005: reads before any change, `halted()` after each.
- ADR-0006 Decision 3, L-SIG-5: views never command or write; RunLog names no sim. ADR-0009 Decision 8: bookkeeping shares 0.2 ms of the tick.
- `BattleBuilder.build(...)` is fixed (ADR-0001). Sim folders read no `OS`, `Time`, `Engine`.

### Requirements
The TRs in GDD Requirements Addressed; text in `tr-registry.yaml`.

## Decision

### 1. The split
All four extend `RefCounted`. The Builder makes the Sims, also headless; only the wrapper makes the Inputs, as plain objects, so tests can build them with a real resolver and no scene.

| Class (file) | Owns | Changes the battle by |
|---|---|---|
| `TowerSim` (`src/feature/tower/tower_sim.gd`) | Gold, slots, towers, `cooldown_left`, one `ReadContext` per built slot plus a scratch, one `DamageEvent`, one `SlotState` per slot, `towers_built`, `slows_applied` | Its own commands and tick |
| `TowerInput` (`src/presentation/tower/tower_input.gd`) | Slot, tower and chip discs, its `ChipWindow`, `chip_state()` and one `ChipState`, signals `slot_tapped(slot_index: int)`, `tower_inspected(slot_index: int)` | `upgrade()` only |
| `HeroSim` (`src/feature/hero/hero_sim.gd`) | Position, pin target, pin and burst state, walk, attack, cooldown and telegraph timers, committed `aim_point`, two `ReadContext`s, one `DamageEvent`, one `HeroCounters` | Its own commands and tick |
| `HeroInput` (`src/presentation/hero/hero_input.gd`) | Hero, button and sink discs; aim state (Idle, Cancelling, Live), aim point, re-clamp, hysteresis, the pin ghost via `PinGeometry.clamp`, the kill preview, `cooldown_digit()`, `update()` | `pin()` and `burst()` only |

- `ChipWindow` (`src/presentation/tower/chip_window.gd`) is TowerInput's (settled 2026-11-04), fed by `tower_input.advance(ms)` in frame step 1.
- `HudLogic` issues `build()` (from the arc), `start_wave()` and `call_early()`; no other `src/` file calls these three (L-CMD-1).
- `burst_button_centre()` is the HUD's. The wrapper builds the HUD first and passes the `Vector2` to `HeroInput.setup()`, read once; tests pass any point (TR-hero-015).
- `PinGeometry` (`src/feature/hero/pin_geometry.gd`) stays pure: `pin()` validates with `is_valid`; HeroInput and bots clamp with `clamp`.
- **HeroInput reads, frame step 1** (ADR-0005 amendment, Migration item 2): in `update()`, between ticks, only in Cancelling and Live: Burst `reach`, `radius`, `damage` through its own `ReadContext`, and Combat `hp_left`, `is_dead` for the preview, each followed by `halted()`. It is the preview's one owner. Order: input delivered before `_process` dispatches (ADR-0004 step 0) before `update()`, else after step 3. Either way `drag_ended` clamps with the current `hero_sim.position()` and the last `update()`'s `reach`, at most one frame old; no stat changes mid-battle at MVP, and `burst()` re-tests reach.
- Sim-to-sim connections use method Callables, never self-capturing lambdas (ADR-0001).

### 2. Result enums
Each command has its own enum on its class: `OK = 0`, `BUSY = 1`, then the GDD's check order. `BUSY` is the result for a call inside a tick or another command; the dev-error text stays `ERR_COMMAND_IN_TICK: <Class>.<command>` (ADR-0004, ADR-0006).

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
- **Order is the order of checks**; the first failing check wins. `HALTED` also follows each read (Decision 3).
- **Compare qualified**: `if r == TowerSim.BuildResult.OK`. Never `if r:` (`OK` is 0, falsy). Never bare `OK`: inside the class, returning it from a `-> BuildResult` function is a parse error (R9), but a caller's `r == OK` parses and is true, because `Error.OK` is 0 by definition, which is why the bug is silent. L-CMD-2 is the only guard there.
- **Flow's `HALTED`** is its phase in WON, LOST or FATAL, the same states where `HaltGate.halted()` is true, so `HALTED` means the same on Flow as on the sims. The battle latch moves Flow to FATAL in `_on_latched` before any command can run. `NOT_BUILD` and `NOT_INTERMISSION` cover PAUSED. `NO_TIME_LEFT` is a call in Intermission at `intermission_left == 0`, reachable only between ticks after a zero-length intermission ("a call at 0 is ignored with no signal").
- `pause()` and `resume()` stay `void`.
- **Callers**: HudLogic and TowerInput keep their UI open on `NO_GOLD` and close on anything else, HudLogic reporting a dev error for codes other than `HALTED` (HUD Rule 7, Tower Rule 8); HeroInput reports anything but `OK` or `HALTED` (Hero Rule 13); bots record every result.

### 3. Commands: checks, reads, commit
Each public command is ADR-0006 Decision 7's shell around a private `_<name>_body()`; on `in_tick()` it reports once and returns `BUSY`.

| Command | Checks in order (after BUSY) | Reads, each followed by `if halted(): return HALTED` | Commit, then emit |
|---|---|---|---|
| `build(slot_index, tower_id)` | `halted()`; `0 <= slot_index < slot count`; `is_tower(tower_id)`; slot empty | scratch `(tower_id, 1)`: `COST`; then `gold < cost` is `NO_GOLD` | `gold -= cost`; slot holds `tower_id` at level 1, `cooldown_left` 0, its own `ReadContext`; its `SlotState` updated; `towers_built += 1`; emit `gold_changed`, `tower_built` |
| `upgrade(slot_index)` | `halted()`; index; slot built; `level < level_count(def_id)` | scratch `(def_id, level + 1)`: `COST`; then `NO_GOLD` | `gold -= cost`; level and context `level` rise, `SlotState` updated; timer unchanged; emit `gold_changed`, `tower_upgraded` |
| `pin(pos)` | `halted()`; `pos` finite; `PinGeometry.is_valid` gives `OUT_OF_BOUNDS` or `BUTTON_ZONE` | Hero context: `WALK_SPEED` | `ever_pinned`; `repins += 1` if pinned before and `pos` differs from `position()`; target, `walk_left`, Walking or Pinned; emit `hero_pinned(pos)` |
| `burst(aim)` | `halted()`; not `in_build()`; pinned once; Ready; finite; inside 0..540, 0..960 inclusive | Burst context: `REACH`, then the squared reach test (`OUT_OF_REACH`); then `TELEGRAPH_DURATION` | `aim_point`; `telegraph_left = max(1, to_ticks(...))`; Telegraphing; emit `burst_started(aim, telegraph_left)` |
| `start_wave()` | phase not terminal; BUILD | none | phase WAVE; injected `start_next_wave()`; emit `phase_changed(WAVE)` |
| `call_early()` | phase not terminal; INTERMISSION; `intermission_left > 0` | none | `seconds_left = intermission_left * dt`; `intermission_left = 0`; WAVE; `start_next_wave()`; emit `wave_called_early(seconds_left)`, `phase_changed(WAVE)` |

- **Read before mutate, every command (TR-tower-006 shared part).** Every read comes before the first write, through the owner's context, and is followed by `halted()`. A bad read latches through the accessor's `fatal`; the command returns `HALTED` with nothing changed. Non-fatal lookups run first, so a bot's bad ID is a refusal, never a fatal.
- **The guard covers listeners**: a handler that commands gets `BUSY`. TowerSim's `_on_wave_called_early` is no command, so it pays inside Flow's guard.
- Flow starts a wave through `EnemyWave.start_next_wave`, injected as a method Callable beside `wave_index()`, since Core cannot name Feature (B9 sync).

### 4. Gold (TR-tower-008, TR-tower-009)
- One `int` `_gold`, never negative, written only by TowerSim: `_init` (`starting_gold`, read directly from Stage), `_on_enemy_killed(bounty)`, `_on_wave_called_early(seconds_left)`, `build`, `upgrade`. Each handler and command checks `halted()` first, so gold freezes once halted. `gold_changed` fires only on a change.
- **`call_bonus(ticks_left: int) -> int`** is a side-effect-free instance method: `ticks_left / to_ticks(early_call_seconds_per_gold)`, truncating (R2), with the Stage rate (at least one tick, Data validator). Instance, not static, because TowerSim already holds the rate and `to_ticks`, so no caller can pass the wrong rate. The handler pays `call_bonus(to_ticks(seconds_left))`; the HUD shows "Call +N" from `call_bonus(flow.intermission_left)`, so shown equals paid (ADR-0004 Decision 4). No burst state is read (Flow Rule 9).

### 5. Run counters (TR-hero-009)
- **HeroSim** owns one `HeroCounters` (`src/feature/hero/hero_counters.gd`): `ever_pinned: bool`, `repins`, `bursts_fired`, `bursts_hit_0`, `bursts_hit_3`, `bursts_hit_5`, `burst_victims`, `burst_kills` (`int`), `kills_per_burst: Array[int]` (one entry per release, 0 included), `kills_on_hit_3: Array[int]`, as Hero Rule 16 defines them. `pin()` sets the first two; the release sets the rest after its delivers (Hero step 7). `counters()` returns the same instance, read-only by contract.
- **TowerSim**: `towers_built() -> int`, `slows_applied() -> int` (Tower Rule 17).
- **The snapshot** (ADR-0006 Decision 9) gains every `HeroCounters` field and `towers_built`, as plain copies, each array `make_read_only()`. HUD Rule 16 reads `ever_pinned`, `towers_built`, `bursts_fired` there.
- **Cost**: counter writes on release ticks, in the 0.2 ms share; the snapshot copy once, in frame step 3.

### 6. HUD read surface (B10; TR-hud-010 shared part)
Side-effect-free queries, read in frame step 3 or a VIEW handler, except HeroInput's own reads in step 1 (Decision 1).

| Owner | Reads |
|---|---|
| Flow | `phase()`, `lives()`, `in_build()`, `intermission_left` (read-only by contract), `result()` |
| TowerSim | `gold()`, `slot_count()`, `slot_state(slot_index) -> SlotState` (`tower_id: StringName`, `&""` empty; `level: int`, 0 empty; `cooldown_left: int`), `call_bonus(ticks_left)`, `towers_built()`, `slows_applied()` |
| TowerInput | `chip_state() -> ChipState` (`open`, `slot_index`, `elapsed_ms`, `level`); signals `slot_tapped`, `tower_inspected` |
| HeroSim | `position()`, `pin_target()`, `pin_state()`, `burst_state()`, `cooldown_left()`, `aim_point()` (committed), `counters()` |
| HeroInput | `aim_state()`, `aim_point()` (live preview), `cooldown_digit()`, the preview's victims and kills |
| EnemyWave | `wave_index()`, `got_through_by_type()`, `roster()`, `targets()` (ADR-0009) |

- `SlotState` is one owned instance per slot, updated at each commit; a bad index returns one shared empty sentinel and reports a dev error once. `ChipState` is one owned instance. Views never keep either past their slot.
- Costs, ranges and Burst `cooldown` come through the accessor in frame step 3 (ADR-0005). ResultScreen and RunLog read only the snapshot, which carries `hero_share`; no view reads `Combat.hero_share()`.

### 7. Bots and the equivalence tests (TR-hero-012; TR-input-014 shared part)
- **Bots call commands directly.** A bot builds with `BattleBuilder.build` and plays a **command script**: `(tick_index, command)` pairs, each applied after `tick_index` ticks and before the next (ADR-0004 Decision 6), then `battle.tick(battle.tick_seconds())`. No resolver or Inputs; results from queries and `take_result_snapshot()`. Bots live in `tests/helpers/bots/` (no `class_name`), used by integration tests, benches or a `tools/` SceneTree script.
- **Resolver equivalence** (`tests/integration/hero/hero_equivalence_test.gd`, Hero AC 27): run A drives a real `InputResolver`, `HeroInput` and `TowerInput` from a tick-indexed gesture script (press, move, release between ticks, `hero_input.update()` before each tick, no adapter or scene). Run B plays the matching command script on a battle from the same `(catalogue, stage_id, rng_seed)`. A command spy records identical `pin`, `burst`, `build`, `upgrade` calls and results, and `battle_state.digest()` plus `counters()` match after every tick. The script holds Hero AC 27's six gestures and one chip upgrade.
- **Never pinned equals absent** (Hero AC 28, rewritten in Migration item 5): building without HeroSim would need a Builder flag, so the test proves absence. On a towers-only script to WON or LOST, each tick, a never-pinned HeroSim makes no read, no Combat call of kind HERO or BURST and no emit, and no field changes. A structural check backs the claim that `Battle.tick` reaches Hero only through `hero_sim.tick()`: lint L-HERO-1 fails any file in `src/foundation/`, `src/core/` or `src/feature/` outside `src/feature/hero/` that names `hero_sim` or `HeroSim`, and any `src/root/` file but `battle.gd`, `battle_builder.gd` and `battle_wrapper.gd`. The wrapper builds HeroInput with `hero_sim` and passes HeroSim to the views and RunMeasures, but runs no tick, so no tick-path file but `battle.gd` reaches `hero_sim` (amended 2026-11-05).

### 8. Dev telemetry: one sink, two logs (TR-hud-013; TR-input-015 shared part; Data Flow 9)
**One gate.** The wrapper builds the sinks, `RunMeasures`, `RunLog` and `GestureLog` only when `OS.is_debug_build()` is true; it is the one owner of the check. Release exports write nothing. Debug exports (tester APKs) write, by intent. The files ship; no export filter.

**The sink.** `class_name JsonlFileSink extends RefCounted`, `src/presentation/dev/jsonl_file_sink.gd`.
```gdscript
func _init(path: String, max_bytes: int = 8 * 1024 * 1024) -> void
## Appends one line. False on a failed open, a failed store or a full file.
## Never reports, never halts; the caller reports its first false once.
func append_line(line: String) -> bool
func close() -> void
```
- Opens on the first line: `READ_WRITE` plus `seek_end()` if it exists, else `WRITE` (T1); keeps the handle. Each line is `store_line` then `flush()`, so a process crash loses no line written (K); `flush` reaches the OS, not always the disk. A failed open is remembered.
- **Cap**: a byte counter seeded from `get_length()` at open; if `counter + line bytes + 1 > max_bytes`, the line is not stored and `append_line` returns `false` from then on. No rotation.
- **Lifetime**: a `Callable` alone does not keep the sink alive (R3), so the wrapper holds each sink in a field until teardown, then calls `close()`.
- One sink each for `user://run_log.jsonl` and `user://gesture_log.jsonl`. Tests inject a recording fake, or a real sink on a missing directory (T2; integration only).
- **Never fatal**: RunLog and GestureLog take `sink.append_line` as a method Callable, report the first `false` once to `dev_error` and go on (ADR-0008 Decision 8).

**Line format.** One `JSON.stringify(dict)` object per line, with `v: 1`, `kind`, `launch_id`, `build`. Writers first replace every non-finite float with `null`, walking nested `Array`s and `Dictionary`s (R8b). AppRoot makes `launch_id` once per launch: `str(int(Time.get_unix_time_from_system()))` plus `-` plus `Crypto.new().generate_random_bytes(4).hex_encode()`, never touching a battle or cosmetic RNG. `build` is `application/config/version`, or `Engine.get_version_info().string` when that is empty (R6). A git-hash stamp at export is a later option.

**RunMeasures** (`src/presentation/dev/run_measures.gd`) names sims so RunLog need not. A VIEW-scope listener in `scopes.gd`, through `view_wiring` (a WIRING signal may take view listeners, ADR-0006 Decision 3). It carries only values the snapshot lacks and never copies a snapshot field:
- real seconds to the first `hero_pinned`, `tower_built` and `burst_started`, from an injected `now_ms` (`Time.get_ticks_msec` in the wrapper);
- per call, from `wave_called_early(seconds_left)`: `seconds_left`, HeroSim's `burst_state()` at that moment (between ticks, so what the player saw) and `flow.lives()`; the record closes with lives lost at the next `wave_cleared` or outcome (HUD Rule 19);
- `best_victims` per release, in its `attack_fired` handler for kind BURST: one plain loop over `targets()` counting, for each target, the others within `radius` by squared distance; it keeps the best count and no list. O(n²) inside a debug tick, so never in HeroSim.

**RunLog** (`src/presentation/dev/run_log.gd`, names no sim, L-SIG-5): `write_call(record: Dictionary)` when RunMeasures closes a call; `write_attempt(snapshot: ResultSnapshot, measures: Dictionary)` once, with the frame step 3 snapshot on WON or LOST, holding HUD Rule 19's fields. A quit leaves no attempt line; FATAL takes no snapshot.

**GestureLog** (ADR-0008 Decision 8): `chip_state` is `TowerInput.chip_state`, `append_line` the gesture sink's.

### Architecture Diagram
```
Bots, HudLogic, TowerInput, HeroInput ─► commands: BUSY? enter ─► checks ─► reads ─► commit ─► emit ─► exit
Debug: RunMeasures ─► RunLog ◄─ snapshot; GestureLog; both ─► append_line ─► JsonlFileSink
```

### Key Interfaces
Decision 2 gives the enums, Decision 6 the queries, ADR-0006 the signals. New signatures (names a GDD does not fix are proposed):
```gdscript
# TowerSim
func build(slot_index: int, tower_id: StringName) -> BuildResult
func upgrade(slot_index: int) -> UpgradeResult
func slot_state(slot_index: int) -> SlotState      # owned per slot; shared empty sentinel if bad; adds cooldown_full: int (amended 2026-11-05)
func call_bonus(ticks_left: int) -> int             # side-effect free
# HeroSim; enum PinState { UNPINNED, WALKING, PINNED }, enum BurstState { READY, TELEGRAPHING, COOLING }
func pin(pos: Vector2) -> PinResult
func burst(aim: Vector2) -> BurstResult
func counters() -> HeroCounters
# Flow
func start_wave() -> StartResult
func call_early() -> CallResult
# TowerInput: setup(resolver, tower_sim, stats, halted, dev_error); advance(ms); chip_state() -> ChipState
# HeroInput: setup(resolver, hero_sim, combat, stats, burst_id, stage, left_handed, button_centre,
#   in_build, halted, dev_error); update(); enum AimState { IDLE, CANCELLING, LIVE }
```

### Implementation Guidelines
1. Every command must have the ADR-0006 shell and return `BUSY` when `in_tick()` is true.
2. Every result enum must start `OK, BUSY`, then the GDD's check order; a new refusal goes in its GDD place.
3. Callers must compare to the qualified `OK`; never `if r:`, never bare `OK` (L-CMD-2).
4. A command must make every lookup, then every read, each read followed by `if halted(): return HALTED`, before its first write.
5. A refusal must change no field, counter or registry and emit nothing.
6. Only TowerSim writes gold; every gold writer checks `halted()` first.
7. Commands are called in `src/` only from their owners' files (L-CMD-1); bots and tests call freely.
8. TowerInput and HeroInput never write a sim field or keep a query result. TowerInput uses only the non-fatal `level_count`; HeroInput reads only as Decision 1 says.
9. In `src/presentation/dev/`, only `jsonl_file_sink.gd` names `FileAccess`; sim folders never do (L-DEV-1). Outside `src/presentation/dev/`, only the wrapper names the dev classes.
10. The wrapper builds every dev object only when `OS.is_debug_build()` is true and holds each sink until teardown; telemetry never commands or writes sim state.
11. A sink failure never reaches `fatal`, `halted()` or a result.
12. Writers replace non-finite floats with `null`, nested values included, before `JSON.stringify`.

## Alternatives Considered

### Alternative 1: One Tower and one Hero object, input optional
- **Description**: one class each. **Pros**: fewer classes. **Cons**: no test can prove input acts only through commands. **Rejection Reason**: TR-tower-001, TR-hero-001 require the split.

### Alternative 2: A command queue drained by `Battle.tick`
- **Description**: the tick applies queued commands. **Pros**: one choke point. **Cons**: results a tick late, so `NO_GOLD` cannot answer its tap. **Rejection Reason**: ADR-0004 Decision 4 rejected the S1 queue.

### Alternative 3: One shared result enum
- **Description**: one `CommandResult`. **Pros**: one type. **Cons**: no per-command check order. **Rejection Reason**: the order is the contract (TR-tower-002, TR-hero-002).

### Alternative 4: RunLog listens to the sims itself
- **Description**: one telemetry class. **Pros**: one file. **Cons**: breaks L-SIG-5. **Rejection Reason**: a sim-blind writer plus RunMeasures keeps the lint.

### Alternative 5: Buffered sink flushed per frame
- **Description**: queue, flush in step 3. **Pros**: no file call in a tick. **Cons**: no real `bool` (ADR-0008); a crash loses the frame (K). **Rejection Reason**: direct writes cost about 2 µs a line, debug only.

## Consequences

### Positive
- Refusals are named, ordered and testable; bots see the codes a thumb does, so bot balance speaks for real play.
- Release builds carry no telemetry; no log failure can touch a battle.

### Negative
- Four classes where a naive design has two, plus three dev classes; `BUSY` and the read-time `HALTED` add a branch to every caller.
- `best_victims` runs long on debug burst-release ticks.

## Risks
- **A refusal appended at the end**: Guideline 2 and the paired-fault tests catch it.
- **Android `user://` write fails**: the first `false` reports once; M2 checks a line on the device.
- **A caller writes `r == OK`**: it compiles; L-CMD-2 catches it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| tower-system.md | TR-tower-001: TowerSim headless; TowerInput acts only through `upgrade` | Decision 1, L-CMD-1 |
| tower-system.md | TR-tower-002: `build`, `upgrade` only, typed result in check order | Decisions 2, 3 |
| tower-system.md | TR-tower-006 (shared): stats read before any mutation | Decision 3. ADR-0001 keeps `halted()` |
| tower-system.md | TR-tower-008: gold owned by TowerSim, frozen once halted | Decision 4 |
| tower-system.md | TR-tower-009: bonus in integer ticks | Decision 4 |
| hero-system.md | TR-hero-001: HeroSim and HeroInput; input only through `pin`, `burst` | Decision 1, L-CMD-1 |
| hero-system.md | TR-hero-002: ordered enums, state before geometry, refusal mutates nothing | Decisions 2, 3 |
| hero-system.md | TR-hero-009: read-only queries, per-run counters | Decisions 5, 6 |
| hero-system.md | TR-hero-012: resolver and direct scripts tick-identical; never-pinned equals absent | Decision 7. The AC 28 and TR text syncs (Migration items 5, 7) have landed |
| hero-system.md | TR-hero-015: `burst_button_centre()` HUD-owned, read once, injectable | Decision 1 |
| battle-hud.md | TR-hud-010 (shared): view-only query surface | Decision 6. ADR-0006 keeps the signals |
| battle-hud.md | TR-hud-013: debug run log, injectable sink, non-fatal failure, no release writes | Decision 8. "Release never writes" unverified until ADR-0007 M4 |
| input-gesture-resolver.md | TR-input-014 (shared): bots call commands, one equivalence test | Decision 7 |
| input-gesture-resolver.md | TR-input-015 (shared): the gesture log's sink | Decision 8 |
| game-state-stage-flow.md | QQ-18: Flow command names and results | Decision 2 |

## Performance Implications
- **CPU**: commands in the 0.5 ms input slice; counter writes in the 0.2 ms share; snapshot copy in step 3; HeroInput reads only while aiming; debug adds about 2 µs a line. **Memory**: a few owned objects. **Load Time**, **Network**: none.

## Migration Plan
No code exists. Sync items, none made here:
1. **`architecture.md`**: B5 Flow enums, QQ-18 resolved; B8 `BUSY`, `slot_state(slot_index) -> SlotState`, `slot_count`, `call_bonus`, counters; B9 `start_next_wave`; B10 per Decision 6 (no `Combat.hero_share()`; preview reads move to HeroInput); RunLog row and Data Flow 9 name RunMeasures and `JsonlFileSink`; B0 snapshot fields; ADR-0010 written.
2. **ADR-0004** Decision 6, **ADR-0006** Decision 7 and V5: the refusal value is `BUSY`, report text unchanged. ADR-0006 Decision 9 lists the new snapshot fields. **ADR-0005** Decision 5 gains: "in frame step 1, by HeroInput, between ticks, only in the Cancelling and Live aim states: Burst `reach`, `radius`, `damage`, and Combat `hp_left`, `is_dead`, each followed by `halted()`"; L-STAT-4 adds `hero_input.gd`.
3. **ADR-0008** Decision 8: `chip_state` is TowerInput's, not TowerSim's.
4. **ADR-0007** lints: **L-CMD-1** on receivers: `tower_sim.build(` and `flow.start_wave(`, `flow.call_early(` only in `hud_logic.gd`; `tower_sim.upgrade(` only in `tower_input.gd`; `hero_sim.pin(`, `hero_sim.burst(` only in `hero_input.gd`. **L-CMD-2**: in those three files and `tests/helpers/bots/`, `if`, `not`, `and`, `or` directly before a command call, and bare `OK` beside a result. **L-DEV-1**: in `src/presentation/dev/` only `jsonl_file_sink.gd` names `FileAccess`; sim folders never do; the full list waits for the save ADR. **L-HERO-1** (Decision 7). `scopes.gd`: `run_measures.gd` as VIEW scope.
5. **GDDs** (game-designer, user sign-off): Tower Rule 5, Hero Rules 2, 6 gain `BUSY` and a read-time `HALTED`; Hero `pin` reads `walk_speed` before commit; Hero AC 28 becomes "never pinned: no read, no Combat call of kind HERO or BURST, no emit, no field change, and `Battle.tick` reaches Hero only through `hero_sim.tick()`"; Game State names `start_wave`, `call_early` and results; HUD Rule 19 names RunMeasures and RunLog, closes calls at the next `wave_cleared` or outcome, and reads "build version" for "build hash"; Tower Rule 17's `slot_state` returns an owned `SlotState`.
6. **`docs/registry/architecture.yaml`**: Proposed entries appended.
7. **`tr-registry.yaml`** (next `/architecture-review`): TR-hero-012's text takes AC 28's isolation wording.

## Validation Criteria
- **V1 Paired faults** (unit): co-occurring faults return the earlier code, each alone too; `BUSY` from a tick, a sim handler and another command; nothing changed or emitted on a refusal.
- **V2 Read before mutate** (spy accessor `fire_fatal_on(1)`): `build`, `upgrade`, `pin`, `burst` return `HALTED` with nothing changed or emitted.
- **V3 Gold**: bonus 8, 7, 0 at 900, 863, 107 ticks and 1.8 s (Tower Formulas); `call_bonus` equals the paid bonus; no `gold_changed` at 0; frozen once halted.
- **V4 Flow**: Game State AC 1, 3, 4, 8, 15 with the new results. **V5 Counters**: Hero AC 16; snapshot copies read-only.
- **V6 Equivalence** (integration): Decision 7. **V7 Never pinned**: the isolation test plus lint L-HERO-1.
- **V8 Sink** (integration): appends, creates; a missing directory gives `false`, no engine message, one caller dev error; the cap gives `false` before the store.
- **V9 Telemetry** (fakes): one attempt line per WON or LOST, one call line per real call; `NAN` and a nested `INF` as `null`; digest identical with telemetry removed (TR-hud-004).
- **Checklist**: release-export no-write joins ADR-0007 M4; lints L-CMD-1, L-CMD-2, L-DEV-1, L-HERO-1 each fail a sample.

## Reviews

| Review | Verdict | Finding | Resolution |
|---|---|---|---|
| godot-specialist | APPROVE | 1, 2, 3, 4 | R9 in Decision 2; `call_bonus` instance, reason given; wrapper holds sinks (R3), method Callables; crash wording |
| | | 5, 7, 11, 18 | Byte-counter cap; one release gate; nested sanitiser, V9; APIs listed |
| TD-ADR | CONCERNS | B1 Never pinned | AC 28 rewrite, TR text sync, L-HERO-1 (Decision 7, Migration 5, 7) |
| | | B2 Preview owner | HeroInput, step 1, aim states only; frame order and stale `reach` stated |
| | | B3 Lints | L-CMD-1 on receivers; L-CMD-2 scoped; R9 noted |
| | | B4 Build field | Version string with engine fallback; HUD Rule 19 sync |
| | | 5 to 14, trims, open items | Applied: Decision 1 wording; owned `SlotState`; V5, `NO_TIME_LEFT`, `HALTED`; RunMeasures scope, close event; L-DEV-1 scope; one gate; step 3 cost; v7; coverage notes; one-loop `best_victims`; V10 to checklist; open items decided |

## Related
- ADR Dependencies lists the ADRs. Supplies ADR-0008 Decision 8's sink; ADR-0011 draws from Decision 6.
- GDDs: those in GDD Requirements Addressed. Open items: none.

## Amendments
- **2026-11-05, with ADR-0011 (confirmed by the user 2026-11-05 at ADR-0011 acceptance); Status stays Accepted.** `SlotState` gains `cooldown_full: int`: the tick count the tower set `cooldown_left` to at its last attack, 0 when empty or not yet fired, and unchanged on upgrade, as the timer is. `architecture.md` B10's Combat row (Decision 6's table has none) also reads `speed_factor(enemy)` and `hp_ratio(enemy)` (ADR-0009 amendment of the same date), for the slow drag lines and the damaged core. Views use them to draw the Cooling ring and the enemy state cues without reading a stat. Nothing else in this ADR changes.
- **2026-11-05, from the fourth architecture review; Status stays Accepted** (`architecture-review-2026-11-05.md`, Conflict 1 and Should fix 5). Decision 7: L-HERO-1 also exempts `src/root/battle_wrapper.gd`, which builds HeroInput with `hero_sim` and passes HeroSim to the views and RunMeasures; the intent stays that no tick-path file but `battle.gd` reaches `hero_sim` (ADR-0007 takes the same row change). The amendment above now names `architecture.md` B10's Combat row, since Decision 6's table has no Combat row. The TR-hero-012 row drops "Full only once": both syncs have landed. Nothing else in this ADR changes.
