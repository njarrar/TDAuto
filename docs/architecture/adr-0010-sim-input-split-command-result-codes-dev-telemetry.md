# ADR-0010: Sim/Input Split, Command Result Codes and Dev Telemetry

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Why this is stated here: stories referencing a `Proposed` ADR are set `Blocked`,
> and epics require `Accepted`, so the field needs a named owner.
> `technical-director` is the role `coordination-rules.md` already escalates
> technical conflicts to, and an ADR is that decision made durable.
>
> This does **not** relax the existing rule that `Status: Accepted` is never set
> without explicit user confirmation. It narrows *which agent* may set it once
> that confirmation exists. An agent that believes an ADR is ready says so and
> escalates; it does not edit this field.

This ADR stays Proposed until: (1) ADR-0004, ADR-0008 and ADR-0009 are Accepted; (2) verification items V1 to V4 below have recorded results in `docs/engine-reference/godot/current-best-practices.md` (V1 and V2 reuse ADR-0008 V8 and V7, so one run closes both); (3) the user confirms the autonomous choices in Decision 12.

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate), godot-specialist (engine check). Authored with the /architecture-decision flow in autonomous mode.

## Summary

Tower and Hero each need a headless sim half (bots, tests) and a wrapper-only input half (resolver gestures, the real-time upgrade chip, aim), and every caller, human or bot, must reach the sim through the same few commands. This ADR fixes the split (`TowerSim`, `HeroSim` in Battle; `TowerInput`, `HeroInput`, `ChipWindow` in the wrapper), the eight commands with their between-ticks check and typed result enums (`OK = 0` first, explicit values, GDD check order), gold ownership, the HUD read surface, the bot script format and equivalence tests, and the development-only run log (`user://run_log.jsonl` through an injectable sink, write failure non-fatal, release never writes).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (pinned 4.7.2) |
| **Domain** | Core (scripting) |
| **Layer** | Core |
| **Knowledge Risk** | LOW. Plain GDScript `RefCounted` classes, enums, signals and `FileAccess`; the only post-cutoff items are already sourced in the pinned reference |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.4 `FileAccess.store_*` returns `bool`; 4.7 typed-return overrides), `deprecated-apis.md` (nothing in this domain), `current-best-practices.md`, `modules/input.md` (no engine input here; adapter is ADR-0003) |
| **Post-Cutoff APIs Used** | `FileAccess.store_string` returning `bool` (4.4, sourced). 4.7 typed-return override rule for test subclasses (`InertHeroSim`, fakes), sourced |
| **Verification Required** | V1 to V4 below |

### Verification items

Owner: godot-specialist writes the scripts; the user runs them headless on 4.7.2 (`godot --headless -s <script>`, outside `src/`) unless a device is named; results go into `current-best-practices.md`. "Expected" is not a source.

- **V1. File append (reuses ADR-0008 V8).** `WRITE` truncates; `READ_WRITE` fails on a missing file; `seek_end()` then `store_string()` appends; `flush()` writes through; `store_string` returns `bool`. Branch: if `READ_WRITE` truncates, `JsonlFileSink` keeps the session's lines in memory and rewrites the file at each flush. No other decision changes.
- **V2. Debug flag (reuses ADR-0008 V7).** `OS.is_debug_build()` is true in an editor run and a debug export and false in a release export (ADR-0001 V4). Branch: if a release export reports true, `DevLogs` creation moves behind an export feature tag (`OS.has_feature`), name decided by the first export story.
- **V3. Where `user://` lands, per platform.** NEEDS VERIFICATION (not in the pinned reference): `OS.get_user_data_dir()` on macOS, Windows, Linux and Android, and whether a tester can copy `run_log.jsonl` off an unrooted Android phone. Method: a debug build writes one line, prints `OS.get_user_data_dir()`, the tester retrieves the file. Owner: the user, first desktop build; first Android build for the phone half. Branch: if the Android file is unreachable, a dev-only "share log" action is added by the Mobile Platform work; desktop MVP is unaffected.
- **V4. Explicit enum values and `typeof`.** `enum BuildResult { OK = 0, HALTED = 1, ... }` parses; a value returned from a typed `-> BuildResult` method records as `TYPE_INT` in the ADR-0007 recording log; `BuildResult.keys()[v]` gives the name for logs. Expected yes (pre-cutoff behaviour, unsourced for 4.7). Branch: logs store the `int` only and tests map names from a `const` table.

Not relied on: `Dictionary` iteration order (no decision reads it; `got_through_by_type()` is looked up by key in a fixed order), sibling `_process` order, any engine timer.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (between-ticks rule, `between_ticks()`, `ticks_run()`, frame order, `to_ticks`, float policy), ADR-0008 (resolver API, registry, `GestureLog`), ADR-0009 (float scalar sim positions, Combat helpers, `targets()`). Binding, also Proposed: ADR-0001 (Builder, injected method Callables, `halted()`, `fatal`, `dev_error`, retry teardown), ADR-0002 (records, `PackedFloat64Array` geometry), ADR-0005 (accessor, `is_tower`, `level_count`, read before mutate), ADR-0006 (signal names, payloads, allowlist, `StageResult`, listener rules), ADR-0007 (battle runner, digest, recording fakes, lint) |
| **Enables** | ADR-0011 (views read the queries fixed here). Every Tower, Hero, Battle HUD and bot story |
| **Blocks** | Every Tower System, Hero System and Battle HUD story; the bot balance gates (Hero Deferred criteria); the Pillar 4 gesture-log harness story's sink choice |
| **Ordering Note** | Write after ADR-0009. ADR-0011 follows. Accept only after ADR-0004, ADR-0008 and ADR-0009 are Accepted. The cascade edits to `architecture.md` B8 to B10 and to three GDDs (cascade notes) land with acceptance |

## Context

### Problem Statement

Tower and Hero rules need real time (the 200 to 1500 ms upgrade chip, the aim drag) and the resolver, yet the battle must run headless and deterministic. Each GDD splits its system in two and leaves to this ADR: where the input halves sit, how bots and humans share one door, what the commands return, who owns gold, what the HUD may read, how a bot script is written, and how development builds record human runs. Without this, Tower and Hero stories cannot start (architecture.md Priority).

### Current State

No code exists. `architecture.md` B8 sketches the enums and commands; B9 and B10 leave four questions open; ADR-0004, ADR-0006, ADR-0008 and ADR-0009 each hand items here (listed in Decision 12 and the cascade notes). Two documents disagree: Tower Rule 17 puts `chip_state()` on TowerInput, `architecture.md` B8 and B10 put it on TowerSim; B8's `pin(pos: Vector2)` and `position()` meet ADR-0009's float-position rule.

### Constraints

- Sims are `RefCounted`, built only by `BattleBuilder.build`, touch no node and never read `Engine`, `Time`, `OS`, a timer or `await` (ADR-0001 B4). So a sim cannot test `OS.is_debug_build()`.
- Commands run only between ticks, never from a tick, a signal listener (gesture listeners G1 to G6 excepted) or `advance`/`update` (ADR-0004; registry `command_inside_tick`, `command_from_sim_or_cancel_listener`).
- All sim positions are float scalar pairs; `Vector2` only at boundaries (registry `sim_position_representation`).
- Read every stat before mutating, `is_tower`/`level_count` first, `halted()` after every read and emit (ADR-0005 Decision 7; ADR-0006 Decision 1).
- Signal names and payloads are ADR-0006's; connections only in `build` or `BattleWrapper.attach` (registry).
- No autoload, no mutable `static var`, method Callables only (registry).
- Solo part-time developer: few classes, no framework.

### Requirements

- One mutation API per system, shared by player input and bots (TR-tower-001, TR-tower-002, TR-hero-001, TR-hero-002, TR-hero-012).
- Typed result codes in the GDD's check order; a refusal mutates and emits nothing.
- Gold: one non-negative `int` on TowerSim, frozen once halted, early-call bonus in integer ticks (TR-tower-008, TR-tower-009).
- Read-only queries and run counters for HUD, bots, logs and Stage Progression (TR-hero-009); `burst_button_centre()` read once and injectable (TR-hero-015).
- A debug-only append log with an injectable sink and a non-fatal write failure (TR-hud-013).
- No measurable tick cost: commands run a few times per frame at most.

## Decision

### 1. The split: two sims in Battle, three input classes in the wrapper

| Class | Folder | Kind | Built by | Holds | Absent headless |
|---|---|---|---|---|---|
| `TowerSim` | `src/feature/tower/` | `RefCounted` | `BattleBuilder.build` | Gold, slot arrays, per-slot `ReadContext`s, `cooldown_left`, `slows_applied`, `build`, `upgrade`, `tick` | No |
| `HeroSim` | `src/feature/hero/` | `RefCounted` | `BattleBuilder.build` | Position, pin target, walk, pin and burst state, timers, aim point, counters, hero and burst contexts, `pin`, `burst`, `tick` | No |
| `PinGeometry` | `src/feature/hero/` | `RefCounted`, pure | HeroSim and HeroInput, one each | Pin rect and active-hand shapes as floats | No |
| `TowerInput` | `src/presentation/tower/` | `RefCounted` | `BattleWrapper.attach` | Slot, tower and chip disc ids; one `ChipWindow`; `slot_tapped`, `tower_inspected` | Yes |
| `ChipWindow` | `src/presentation/tower/` | `RefCounted`, pure | TowerInput | Open slot, elapsed ms | Yes |
| `HeroInput` | `src/presentation/hero/` | `RefCounted` | `BattleWrapper.attach` | Hero, button and sink disc ids; aim state (Idle, Cancelling, Live); aim point; ghost; digit | Yes |

- TowerInput and HeroInput are plain objects, not nodes, so tests construct them on a headless battle with the real `battle.resolver` (ADR-0008 builds it in Builder step 2) or a `FakeResolver`. "Absent headless" means the Builder never makes them; the equivalence test makes HeroInput itself.
- TowerInput changes battle state only through `tower_sim.upgrade`; HeroInput only through `hero_sim.pin` and `hero_sim.burst`; HudLogic only through `tower_sim.build`, `flow.start_wave`, `flow.call_early`. No input class writes a sim field or calls a tick entry.
- The wrapper builds them in `attach`, after HudLogic (HeroInput needs `burst_button_centre()`), connects their listeners in `_connect_signals()`, and in `detach()` calls each one's `detach()` (unregister its discs, drop every reference) before dropping it. Retry then frees the old battle; ADR-0001's weakref test covers both classes.
- The wrapper feeds TowerInput in frame step 1 (`tower_input.advance(ms)`) and syncs HeroInput first in step 4 (`hero_input.update()`), as ADR-0004 Decision 5 fixed.

### 2. Eight commands, checked between ticks

The complete MVP command set: `TowerSim.build`, `TowerSim.upgrade`, `HeroSim.pin`, `HeroSim.burst`, `Flow.start_wave`, `Flow.call_early`, `Flow.pause`, `Flow.resume`. This is ADR-0007 WIRE-9's list unchanged; no new command is added.

**Enforcement.** The Builder injects `between_ticks: Callable` (`battle.between_ticks`, a method Callable like `halted`) into TowerSim, HeroSim and Flow. Every command's first statement is:

```gdscript
if not _between_ticks.call():
    _fatal.call("command inside tick: TowerSim.build")
    return BuildResult.HALTED
```

`pause()` and `resume()` return after the `fatal` call. The check runs in every build, because a sim may not read `OS.is_debug_build()` and a command inside a tick would break determinism silently in release. It costs one call per command. `fatal` makes `halted()` true, so `HALTED` is the honest return. This closes ADR-0004's "ADR-0010 decides enforcement" (item 15).

### 3. Result enums

Rules: `OK = 0` first; every value written explicitly; declaration order after `OK` is the GDD's check order; values are never renumbered or reused; a new check takes the next unused number and is declared in its check position. Logs and bot results store the `int`; names come from `keys()` (V4).

```gdscript
# TowerSim
enum BuildResult   { OK = 0, HALTED = 1, BAD_SLOT = 2, BAD_TOWER = 3, SLOT_OCCUPIED = 4, NO_GOLD = 5 }
enum UpgradeResult { OK = 0, HALTED = 1, BAD_SLOT = 2, NO_TOWER = 3, MAX_LEVEL = 4, NO_GOLD = 5 }
# HeroSim
enum PinResult     { OK = 0, HALTED = 1, BAD_POSITION = 2, OUT_OF_BOUNDS = 3, BUTTON_ZONE = 4 }
enum BurstResult   { OK = 0, HALTED = 1, BUILD_PHASE = 2, NOT_PINNED = 3, NOT_READY = 4,
                     BAD_POSITION = 5, OFF_FIELD = 6, OUT_OF_REACH = 7 }
# Flow (QQ-18 resolved)
enum StartResult   { OK = 0, HALTED = 1, NOT_BUILD = 2 }
enum CallResult    { OK = 0, HALTED = 1, NOT_INTERMISSION = 2, NOTHING_LEFT = 3 }
```

`StartResult.NOT_BUILD` is Game State's "a second tap finds no Build and is ignored"; `CallResult.NOTHING_LEFT` is "a call at 0 is ignored with no signal". `pause()` and `resume()` keep `-> void` (bots never pause; Flow's own state rules decide). `PinGeometry.is_valid` returns `HeroSim.PinResult` (`OK`, `OUT_OF_BOUNDS` or `BUTTON_ZONE`).

### 4. Command bodies

Common shape, binding for all eight: (0) between-ticks check; (1) `halted()` → `HALTED`; (2) state checks; (3) geometry or ID checks, through non-fatal lookups only; (4) every stat read, each followed by `halted()` → `HALTED`; (5) remaining checks that need the values; (6) commit every field and counter; (7) emit, `halted()` after each emit, skipping later emits if true; (8) return `OK`. A return before step 6 changes nothing and emits nothing. Read contexts are never created in a command: TowerSim keeps one command context (`_cost_ctx`, made at construction) whose `def_id` and `level` it sets before a cost read (ADR-0005 Decision 4 allows the owner to change them).

| Command | Steps 2 to 5 | Step 6 commit | Step 7 emits |
|---|---|---|---|
| `build(slot_index, tower_id)` | `BAD_SLOT` if `slot_index < 0 or >= slot_count()`; `BAD_TOWER` if `not accessor.is_tower(tower_id)`; `SLOT_OCCUPIED`; read `COST` at level 1; `NO_GOLD` if `gold < cost` | `gold -= cost`; slot gets `tower_id`, level 1, `cooldown_left` 0 (Rule 11, starts ready), its `ReadContext.make(tower_id, 1)` | `gold_changed(gold)` only if `cost != 0`; `tower_built(slot_index, tower_id)` |
| `upgrade(slot_index)` | `BAD_SLOT`; `NO_TOWER`; `MAX_LEVEL` if `level >= accessor.level_count(def_id)`; read `COST` at `level + 1`; `NO_GOLD` | `gold -= cost`; `level += 1`; slot context `level` updated; `cooldown_left` untouched (Rule 12) | `gold_changed(gold)` if changed; `tower_upgraded(slot_index, level)` |
| `pin(pos)` | `BAD_POSITION` if `x` or `y` not finite; `OUT_OF_BOUNDS`, `BUTTON_ZONE` from `PinGeometry.is_valid(x, y)`; read `WALK_SPEED` | Walk from the current position: `walk_ticks` per Hero Formulas (`ceili`), state Walking, or Pinned at once when the distance is 0; `repins += 1` only if a pin was already made and the distance is above 0; `_has_pinned = true` | `hero_pinned(Vector2(target))` |
| `burst(aim)` | `BUILD_PHASE` if `in_build()`; `NOT_PINNED` if no pin has returned `OK`; `NOT_READY` unless Ready; `BAD_POSITION`; `OFF_FIELD` outside 0 to 540, 0 to 960 inclusive; read `REACH`, then `OUT_OF_REACH` on squared distance from the current position, inclusive; read `TELEGRAPH_DURATION` | Aim point stored as floats; `telegraph_left = maxi(1, to_ticks(td))`; state Telegraphing | `burst_started(Vector2(aim), telegraph_left)` |
| `start_wave()` | `NOT_BUILD` unless phase is BUILD | Flow's (ADR-0004, ADR-0006) | Flow's |
| `call_early()` | `NOT_INTERMISSION`; `NOTHING_LEFT` if `intermission_left == 0` | Flow's | `wave_called_early(seconds_left)` (W5) before `phase_changed(WAVE)` (ADR-0006) |

Edge results fixed by these bodies, each a GDD edge case: exact gold buys and leaves 0; two `upgrade` calls with gold for one give `OK` then `MAX_LEVEL`; a bad `COST` read halts and returns `HALTED` with gold and slots unchanged; a pin at the hero's own position is `OK`, Pinned at once, and counts as the first pin but not as a repin; `burst` during a telegraph is `NOT_READY`.

**Handling results in input code.** HudLogic's arc (Battle HUD Rule 7) and TowerInput's chip (Tower Rule 8): `OK` closes; `NO_GOLD` stays open; `HALTED` closes; anything else closes and calls `dev_error` with the enum name. HeroInput: `OK` and `HALTED` are normal; anything else is a `dev_error` (Hero Rule 13). Bots record every result (Decision 9).

### 5. Positions at the command boundary

- `pin(pos: Vector2)` and `burst(aim_point: Vector2)` keep `Vector2` arguments, as ADR-0009 allows: line one after the checks of Decision 4 step 0 and 1 reads `var x: float = pos.x` and `var y: float = pos.y`; nothing else touches `pos`. Every stored position (hero position, walk origin, pin target, aim point) is a `float` pair; slot origins are read from `StageRecord.slot_positions` (`PackedFloat64Array`, ADR-0002), never copied into `Vector2`.
- Reason for `Vector2` over `(x, y)` arguments: the resolver hands `Vector2` payloads (ADR-0008 Decision 3), the Hero GDD's `clamp_pin` "arrives and leaves as `Vector2`" with margins sized for 32-bit rounding, and bots and HeroInput then pass the same type, so the equivalence test compares like with like.
- HeroInput computes the aim point, the reach clamp and the ghost in `float` scalars (finger plus offset, field clamp, reach clamp to `reach - 0.01`) and builds a `Vector2` only for the command call, so no `Vector2` operator decides what a command receives.
- Queries that return positions return a new `Vector2` built from the floats (`position()`, `pin_target()`, `slot_position(i)`). They are view and bot reads; sim code never calls them. The registry entry `sim_position_representation` gains "query returns for views and bots" in its allowed list (cascade).

### 6. Gold

- `TowerSim._gold: int` is the only gold. Set once at construction from `StageRecord.starting_gold` (a direct read, ADR-0005 Decision 8); no `gold_changed` at construction; the HUD reads `gold()` in `attach`.
- Faucets: `on_enemy_killed(bounty)` (W2) and `on_wave_called_early(seconds_left)` (W5). Sinks: `build`, `upgrade`. Nothing else writes it. No faucet adds a negative amount; a sink checks `gold >= cost` first, so gold never goes below 0.
- Both listeners return at once if `halted()` (gold freezes; a fatal leak skips the reap anyway, ADR-0004), add nothing when the amount is 0, emit `gold_changed(gold)` only on a change, then check `halted()`.
- Early-call bonus (TR-tower-009): `_rate_ticks = to_ticks(stage.early_call_seconds_per_gold)` once at construction (structural field, not a stat; if below 1, `fatal("stage: early_call_seconds_per_gold under one tick")`, which ADR-0002's boot check already prevents for real data). The listener computes `to_ticks(seconds_left) / _rate_ticks`, both `int`, integer division under `@warning_ignore("integer_division")`. Flow sends `seconds_left = intermission_left * dt`, and `to_ticks` returns `intermission_left` exactly for every value up to 600 s (ADR-0004 Validation 3 covers the round trip).
- The bonus reads no burst state and no Flow state (Flow Rule 9).

### 7. The read surface (B10 settled)

Every read below is read-only, allocates nothing unless stated, and is safe to call from views, the HUD, bots, logs and tests. None calls `fatal` except where it reads the accessor, as noted.

| Owner | Reads |
|---|---|
| TowerSim | `gold() -> int`; `slot_count() -> int`; `slot_tower(i) -> StringName` (`&""` empty); `slot_level(i) -> int` (0 empty); `slot_cooldown_left(i) -> int`; `slot_position(i) -> Vector2`; `slows_applied() -> int`; `state_fields() -> Dictionary` |
| HeroSim | `position() -> Vector2`; `pin_target() -> Vector2` (`hero_start` before a first pin); `pin_state() -> PinState`; `burst_state() -> BurstState`; `cooldown_left() -> int`; `hero_id() -> StringName`; `burst_id() -> StringName`; counters (below); `state_fields() -> Dictionary` |
| TowerInput | `chip_state() -> TowerInput.ChipState`; `is_chip_open() -> bool`; signals `slot_tapped(slot_index: int)`, `tower_inspected(slot_index: int)` |
| HeroInput | `aim_state() -> AimState`; `aim_point() -> Vector2`; `cooldown_digit() -> int` |
| Flow, EnemyWave, Combat | As B5, B7 and B6: `phase()`, `lives()`, `intermission_left`, `result()`, `in_build()`; `wave_index()`, `got_through_by_type()`, `targets()`; `hero_share()`, `dealt_by_kind()`, `dealt_total()` |

Settled items:

- **`chip_state()` belongs to TowerInput** (Tower Rule 17 is right; B8 and B10 are corrected). The window runs on real time and lives in the wrapper; TowerSim is headless and has no window. `ChipState` is an inner value class (`open: bool`, `slot_index: int` (-1 closed), `elapsed_ms: float`, `level: int`), one instance per TowerInput refreshed on each call; callers read it in the handler or frame and never keep it.
- **Slot reads are per field** (`slot_tower(i)` and the rest) instead of B8's `slot_state() -> Array` and the GDD's `slot_state(slot_index)`: typed, no allocation per frame. A bad `i` returns the empty value and calls `dev_error` once per read site; never `fatal`.
- **Counters** (Hero Rule 16, TR-hero-009), all on HeroSim, updated in `pin` and at release only: `repins()`, `bursts_fired()`, `bursts_hit_0()`, `bursts_hit_3()`, `bursts_hit_5()`, `burst_victims()`, `burst_kills()`, `kills_per_burst() -> PackedInt32Array`, `kills_on_hit_3() -> PackedInt32Array`, `best_victims() -> PackedInt32Array`. The array reads return copies (a log or the snapshot reads them once). `best_victims` (the most `targets()` any disc of burst `radius` centred on an enemy holds at release) is computed in every build, because a sim cannot test for a debug build; it costs at most 48 x 48 squared-distance tests once per release. Counters freeze with the battle.
- **The cooldown total** (B10's "cooldown total"). HudLogic computes it as ADR-0005 Decision 7 already says: `to_ticks(stat_float(burst_ctx, StatKeys.COOLDOWN))`, with its own burst `ReadContext` made in `attach` from `hero_sim.burst_id()`, `to_ticks` from `battle.sim_time`, and `halted()` after the read. ADR-0010 adds `HeroSim.hero_id()` and `burst_id()` (the IDs the Builder already injects, Hero Rule 8), so the wrapper side needs no catalogue lookup. A `HeroSim.cooldown_total()` was rejected (Alternative 4).
- **`wave_index()` and `got_through_by_type()`** are ratified as ADR-0009 defined them. `got_through_by_type()` returns `Dictionary` (`StringName` def_id to `int`); readers look types up in the Wave records' fixed order and never iterate it.
- **`state_fields()`** returns every field of the sim as JSON-native values (floats, ints, arrays) for ADR-0007's `digest`, the equivalence test and the run log. It allocates; no gameplay code calls it.

### 8. Input-side bindings

**TowerInput** (Tower Rules 8, 17; Battle HUD Rule 9). `attach(resolver, tower_sim, accessor, halted: Callable, dev_error: Callable)`.

- Registers one TAP disc per slot (priority 200, slot radius per Input GDD). Listens to `tower_sim.tower_built` (P4; consumer added to ADR-0006's table): disables that slot's disc and registers the tower's TAP disc at the same centre.
- `_on_tapped(best_tap, p)`: returns at once if `halted.call()` (TR-tower-011; **`halted()` is now injected into TowerInput** by the wrapper, B9 cascade). Empty slot: emits `slot_tapped(slot_index)`. Tower below `accessor.level_count(def_id)`: opens or commits the chip per Rule 8's table. Tower at its last level: emits `tower_inspected(slot_index)`.
- `ChipWindow`: `open(slot_index)`, `close()`, `advance(ms: float)` (ignores non-finite or negative ms), `is_open()`, `slot()`, `elapsed_ms()`, `can_commit() -> bool` (`200 <= elapsed < 1500`). `MIN_COMMIT_MS := 200.0` and `WINDOW_MS := 1500.0` are `const` presentation constants (Data Rule 1). `TowerInput.advance(ms)` calls it and, on expiry, unregisters the chip disc (registry calls are legal at any time, ADR-0008).
- `_on_pressed`: applies Rule 8's close rules. `_on_phase_changed`: closes on PAUSED, WON, LOST, FATAL.
- `GestureLog`'s `chip_open` Callable (ADR-0008 Decision 8) is wired by the wrapper as `tower_input.is_chip_open`.

**HeroInput** (Hero Rules 11 to 15). `attach(resolver, hero_sim, accessor, halted: Callable, in_build: Callable, left_handed: bool, stage: StageRecord, burst_button_centre: Vector2, dev_error: Callable)`.

- `burst_button_centre` is a value, read once by the wrapper from `hud_logic.burst_button_centre()` and passed in; tests pass any point (TR-hero-015). It sets the button and sink disc centres and the cancel ring's 64 and 48.
- Registers hero (DRAG 200, r 56), button (DRAG 100, r 48), sink (TAP 400, r 48). `update()` (frame step 4) calls `set_centre` for the hero from `position()`, re-clamps the aim and refreshes the digit.
- Reads Burst `REACH` through its own burst context (made in `attach`) when it clamps an aim, with `halted()` after the read; a halted read ends the aim.
- Issues `pin` on `drag_ended` of a hero drag, with `PinGeometry.clamp` of the offset finger; issues `burst` on `drag_ended` of a Live aim. `drag_cancelled` and `became_idle` clear state and never issue a command.

### 9. Bots and equivalence (TR-hero-012, Input Rule 11)

**One door.** A bot is any object passed to ADR-0007's `battle_runner.run(battle, ticks, between)` as `bot.between`. Its `between(i: int) -> void` may call only the six gameplay commands of Decision 2 (bots never pause) and the reads of Decision 7, plus `PinGeometry` and the accessor's reads. It never writes a field, connects a signal or calls a tick entry. Bots live in `tests/bots/` (exported only by the dev preset that ADR-0004 V5's phone bot-run entry needs; ADR-0007 owns presets).

**Script format.** Steps fire by `battle.ticks_run()`, as ADR-0004 Decision 4 fixed:

```gdscript
# tests/bots/command_step.gd
class_name CommandStep extends RefCounted
var at_tick: int                 # fires when ticks_run() >= at_tick, once, in array order
var command: StringName          # &"build", &"upgrade", &"pin", &"burst", &"start_wave", &"call_early"
var slot_index: int = -1
var tower_id: StringName = &""
var x: float = 0.0               # pin and burst only; passed as Vector2(x, y)
var y: float = 0.0
```

`ScriptBot` holds an `Array[CommandStep]` sorted by `at_tick` and a cursor; each `between` call issues every unfired step with `at_tick <= ticks_run()` and appends the result code to `results: PackedInt32Array`. In Build, `ticks_run()` stays 0, so a script's build-phase steps and its `start_wave` all sit at tick 0. The text form, for baselines, is one JSON object per step with the same keys. Policy bots (mid-skill, ceiling, pinned once, best single pin; Hero Simulated results) extend the same `Bot` base and decide from reads each call; their parameters are `const` in the bot file, not catalogue values.

**Equivalence test** (Hero criterion 27). A gesture script is an `Array[GestureStep]` (`at_tick`, `call`: press, move, release or cancel_pointer, `pointer`, `x`, `y`). Route A: a headless battle, a real `HeroInput` attached to `battle.resolver` with a test `burst_button_centre`; each runner step calls the resolver for that tick's steps, then ticks, then `hero_input.update()`. Route B: the same battle inputs with a `ScriptBot` whose `pin` and `burst` steps carry the positions route A's HeroInput computed (fingers chosen so no clamp moves them). After every tick, `hero_sim.state_fields()`, the counters and a recording fake's log of HeroSim's signals are equal. TowerInput's wiring is proven separately with a `FakeResolver` (Tower Rule 17).

**Never pinned equals absent** (Hero criterion 28). "Absent" is `InertHeroSim extends HeroSim` (in `tests/helpers/`) whose `tick()` does nothing and returns (typed-return rule); the test swaps `battle.hero_sim` right after `build` (test code may). Production code has no absent branch. Both runs keep per-tick lives, gold, roster, slots, the `deliver` and `attack_fired` logs and the spy accessor's read log equal, and the real HeroSim's `state_fields()` stay at their initial values.

### 10. Development telemetry: the run log

**Files and sink.** Two files, one sink class: `user://run_log.jsonl` (this ADR) and `user://gesture_log.jsonl` (ADR-0008's `GestureLog`). This settles ADR-0008 choice 7: no merge. The class is `JsonlFileSink` (`src/presentation/dev/jsonl_file_sink.gd`, `RefCounted`), implementing ADR-0008 V8 exactly: `static func open(path: String) -> JsonlFileSink` returns null when `not OS.is_debug_build()` or when the file cannot be opened (`READ_WRITE` if it exists, else `WRITE`; `seek_end()`; one handle); `write_line(text: String) -> bool` stores `text + "\n"`, checks the `store_string` `bool`, then `flush()`; `close()`.

**Session object.** In debug builds AppRoot creates one `DevLogs` (`src/root/dev_logs.gd`, `RefCounted`) at boot: `launch_id: int` (`int(Time.get_unix_time_from_system() * 1000.0)`, the read ADR-0004 V8 sources), `build_hash: String` (the `const BUILD_HASH` in `src/root/build_info.gd`, `"dev"` in the repo, overwritten by the export script before a debug export; no engine API), `run_sink` and `gesture_sink`. It holds no battle object and no battle Callable, so it may live for the session (registry `session_object_holds_battle_callable_v2`). In release AppRoot creates none. `BattleWrapper.attach(battle, reduce_motion, dev_logs: DevLogs = null)` gains the optional argument; with null, neither log node is created.

**RunLog** (`src/presentation/dev/run_log.gd`, `extends Node`, created by `attach` only with `dev_logs`). `attach(battle, sink: Callable, launch_id: int, build_hash: String, dev_error: Callable)`; the wrapper passes `dev_logs.run_sink.write_line`, or an invalid `Callable()` if the sink is null. Tests pass a recording fake's method.

- A view listener (ADR-0006 rule 2): it listens to P1 `phase_changed`, P4 `tower_built`, P6 `hero_pinned`, P7 `burst_started` (all allowlisted) and reads queries. It issues no command and writes no sim state. It stamps `Time.get_ticks_msec()` in its handlers for the real seconds to first build, pin and burst since `attach` (Paused time included; accepted for a dev metric). `src/presentation/dev/` is already outside the `engine_time_in_sim` lint (ADR-0008 cascade).
- **Attempt record**, one per WON or LOST: HudLogic calls its injected `snapshot_taken: Callable` with the `ResultSnapshot` (Decision 11), wired to `run_log.on_snapshot_taken`; RunLog adds its real-time fields and writes. Screen and log read the same snapshot (Battle HUD Rule 15). A FATAL outcome or a quit writes none (Rule 19 accepts this).
- **Call record**, one per `CallResult.OK`: HudLogic, the only caller of `call_early` in a human run, reads `flow.intermission_left` and `hero_sim.burst_state()` just before the call and, on `OK`, calls its injected `call_made: Callable` (`run_log.on_call_made(ticks_left: int, burst_state: int)`). RunLog reads `flow.lives()` then and again at the next `phase_changed` to INTERMISSION, WON or LOST, and writes `seconds_left`, `ticks_left`, burst state and lives lost. This avoids connecting the wrapper to W5, which is not on the view allowlist.
- Record fields, all JSON-native, no `Vector2`: `kind` (`"attempt"` or `"call"`), `launch_id`, `build_hash`, `stage_id`, `rng_seed` (ADR-0004: dev builds log the seed), `ticks_run`; then Rule 19's lists. Written with `JSON.stringify(record, "", true, true)` (sorted keys, full precision; ADR-0002's form).
- **Failure is never fatal.** An invalid sink, or a `write_line` returning `false`, calls `dev_error` once per RunLog with the path and keeps play going; later lines are still attempted. RunLog never calls `fatal`, and nothing it does reaches a sim. HudLogic's two Callables default to `Callable()` and are called only after `is_valid()`, so release HudLogic is unchanged.

### 11. The HUD result snapshot

`ResultSnapshot` (`src/presentation/hud/result_snapshot.gd`, `RefCounted`, values only, no signal) is built by HudLogic at the moment ADR-0006 Decision 6 fixed (first `advance` after `phase_changed(WON)` or `(LOST)`). Fields: `result: StageResult`; `stage_id: StringName`; `rng_seed: int`; `ticks_run: int`; `got_through: Dictionary` (a copy); `slows_applied: int`; `towers_built: int` (built slots counted from slot reads); `hero_pinned_ever: bool` (`pin_state() != UNPINNED`); `hero_share: float`; the ten Hero counters (arrays copied). It references no sim object, so a view may keep it after the battle is dropped. The Next-try line (Battle HUD Rule 16) and the result rows read only it.

### 12. Choices made in autonomous mode

Each can be overturned (cascade section d):

1. Between-ticks check in every build, `fatal` plus `HALTED`, not a debug-only check (Decision 2).
2. Explicit enum values (Decision 3); `StartResult` and `CallResult` names and codes (QQ-18).
3. `chip_state()` on TowerInput (Decision 7); per-field slot reads replace `slot_state` (rename).
4. Cooldown total stays HUD-computed through the accessor; HeroSim gains `hero_id()` and `burst_id()` instead of `cooldown_total()`.
5. `best_victims` computed in every build.
6. `Vector2` command arguments, not `(x, y)` pairs (Decision 5).
7. Bot steps keyed by `ticks_run()` with a cursor; bots in `tests/bots/`.
8. "HeroSim absent" modelled by a test-only `InertHeroSim`, no production branch.
9. Two log files, one sink class; call records fed by HudLogic, not a W5 connection.
10. TowerInput listens to P4 `tower_built` to swap slot and tower discs.
11. `launch_id` from the session's unix-millisecond read; `build_hash` from a stamped `const`.

### Architecture Diagram

```
 BattleBuilder.build (headless)                         BattleWrapper.attach (absent headless)
 ┌──────────────── Battle ─────────────────┐          ┌───────────────────────────────────────┐
 │ Flow ── W5 wave_called_early ─┐          │          │ HudLogic ── build / start_wave / call │
 │   start_wave call_early       ▼          │ commands │ TowerInput ── upgrade                 │
 │ EnemyWave ─ W2 enemy_killed ► TowerSim ◄─┼──────────┤   ChipWindow (advance(ms), step 1)    │
 │                      gold, slots, build, │ (step 0, │ HeroInput ── pin / burst              │
 │                      upgrade, tick       │ between  │   update() step 4, PinGeometry        │
 │ HeroSim ◄────────────────────────────────┼─ ticks)  │ RunLog, GestureLog (debug only)       │
 │   pin, burst, tick, counters             │          │   └─► JsonlFileSink (DevLogs, session)│
 │ resolver (ADR-0008) ─ G1..G8 ────────────┼─────────►│ listeners _on_<signal>                │
 │ injected: halted, between_ticks, fatal,  │ P1..P9   │ reads: Decision 7 (never writes)      │
 │ to_ticks, in_build, targets, dev_error   ├─────────►│                                       │
 └──────────────────────────────────────────┘          └───────────────────────────────────────┘
   bots (tests/bots): battle_runner ─ between(i) ─► the same six commands; reads only
```

### Key Interfaces

```gdscript
# src/feature/tower/tower_sim.gd
class_name TowerSim extends RefCounted
enum BuildResult   { OK = 0, HALTED = 1, BAD_SLOT = 2, BAD_TOWER = 3, SLOT_OCCUPIED = 4, NO_GOLD = 5 }
enum UpgradeResult { OK = 0, HALTED = 1, BAD_SLOT = 2, NO_TOWER = 3, MAX_LEVEL = 4, NO_GOLD = 5 }
signal gold_changed(current: int)                               # P3
signal tower_built(slot_index: int, tower_id: StringName)       # P4
signal tower_upgraded(slot_index: int, level: int)              # P5
func _init(stage: StageRecord, accessor: StatAccessor, halted: Callable, between_ticks: Callable,
           targets: Callable, to_ticks: Callable, combat: Combat, fatal: Callable, dev_error: Callable) -> void
func build(slot_index: int, tower_id: StringName) -> BuildResult
func upgrade(slot_index: int) -> UpgradeResult
func tick() -> void                                             # Battle step 4 only
func on_enemy_killed(bounty: int) -> void                       # W2 only
func on_wave_called_early(seconds_left: float) -> void          # W5 only
func gold() -> int
func slot_count() -> int
func slot_tower(slot_index: int) -> StringName
func slot_level(slot_index: int) -> int
func slot_cooldown_left(slot_index: int) -> int
func slot_position(slot_index: int) -> Vector2
func slows_applied() -> int
func state_fields() -> Dictionary

# src/feature/hero/hero_sim.gd
class_name HeroSim extends RefCounted
enum PinResult   { OK = 0, HALTED = 1, BAD_POSITION = 2, OUT_OF_BOUNDS = 3, BUTTON_ZONE = 4 }
enum BurstResult { OK = 0, HALTED = 1, BUILD_PHASE = 2, NOT_PINNED = 3, NOT_READY = 4,
                   BAD_POSITION = 5, OFF_FIELD = 6, OUT_OF_REACH = 7 }
enum PinState   { UNPINNED, WALKING, PINNED }
enum BurstState { READY, TELEGRAPHING, COOLING }
signal hero_pinned(position: Vector2)                           # P6
signal burst_started(aim_point: Vector2, telegraph_ticks: int)  # P7
func _init(stage: StageRecord, hero_id: StringName, burst_id: StringName, left_handed: bool,
           accessor: StatAccessor, halted: Callable, between_ticks: Callable, in_build: Callable,
           targets: Callable, to_ticks: Callable, dt: float, combat: Combat, fatal: Callable) -> void
func pin(pos: Vector2) -> PinResult
func burst(aim_point: Vector2) -> BurstResult
func tick() -> void                                             # Battle step 5 only
func position() -> Vector2
func pin_target() -> Vector2
func pin_state() -> PinState
func burst_state() -> BurstState
func cooldown_left() -> int
func hero_id() -> StringName
func burst_id() -> StringName
func repins() -> int
func bursts_fired() -> int
func bursts_hit_0() -> int
func bursts_hit_3() -> int
func bursts_hit_5() -> int
func burst_victims() -> int
func burst_kills() -> int
func kills_per_burst() -> PackedInt32Array      # copy
func kills_on_hit_3() -> PackedInt32Array       # copy
func best_victims() -> PackedInt32Array         # copy
func state_fields() -> Dictionary

# src/feature/hero/pin_geometry.gd
class_name PinGeometry extends RefCounted
func _init(stage: StageRecord, left_handed: bool) -> void     # rect and active-hand shapes as floats
func is_valid(x: float, y: float) -> HeroSim.PinResult        # OK, OUT_OF_BOUNDS or BUTTON_ZONE
func clamp(fx: float, fy: float, hold_x: float, hold_y: float) -> Vector2   # clamp_pin; Vector2 out

# src/core/flow/flow.gd (adds to B5)
enum StartResult { OK = 0, HALTED = 1, NOT_BUILD = 2 }
enum CallResult  { OK = 0, HALTED = 1, NOT_INTERMISSION = 2, NOTHING_LEFT = 3 }
func start_wave() -> StartResult
func call_early() -> CallResult
# Builder also injects between_ticks (battle.between_ticks)

# src/presentation/tower/tower_input.gd
class_name TowerInput extends RefCounted
class ChipState extends RefCounted:
    var open: bool = false
    var slot_index: int = -1
    var elapsed_ms: float = 0.0
    var level: int = 0
signal slot_tapped(slot_index: int)
signal tower_inspected(slot_index: int)
func attach(resolver: InputResolver, tower_sim: TowerSim, accessor: StatAccessor,
            halted: Callable, dev_error: Callable) -> void
func detach() -> void
func advance(ms: float) -> void                  # frame step 1; feeds ChipWindow
func chip_state() -> ChipState                   # reused instance; read, never keep
func is_chip_open() -> bool                      # GestureLog's chip_open
func _on_pressed(best_tap: int, best_drag: int, p: Vector2) -> void
func _on_tapped(best_tap: int, p: Vector2) -> void
func _on_phase_changed(value: Flow.Phase) -> void
func _on_tower_built(slot_index: int, tower_id: StringName) -> void

# src/presentation/tower/chip_window.gd
class_name ChipWindow extends RefCounted
const MIN_COMMIT_MS := 200.0
const WINDOW_MS := 1500.0
func open(slot_index: int) -> void
func close() -> void
func advance(ms: float) -> void
func is_open() -> bool
func slot() -> int
func elapsed_ms() -> float
func can_commit() -> bool

# src/presentation/hero/hero_input.gd
class_name HeroInput extends RefCounted
enum AimState { IDLE, CANCELLING, LIVE }
func attach(resolver: InputResolver, hero_sim: HeroSim, accessor: StatAccessor, halted: Callable,
            in_build: Callable, left_handed: bool, stage: StageRecord,
            burst_button_centre: Vector2, dev_error: Callable) -> void
func detach() -> void
func update() -> void                            # frame step 4, first
func aim_state() -> AimState
func aim_point() -> Vector2
func cooldown_digit() -> int
# listeners: _on_pressed, _on_drag_started, _on_drag_moved, _on_drag_ended, _on_drag_cancelled, _on_became_idle

# src/presentation/dev/jsonl_file_sink.gd, run_log.gd; src/root/dev_logs.gd
class_name JsonlFileSink extends RefCounted
static func open(path: String) -> JsonlFileSink  # null in release or on failure
func write_line(text: String) -> bool
func close() -> void
class_name RunLog extends Node
func attach(battle: Battle, sink: Callable, launch_id: int, build_hash: String, dev_error: Callable) -> void
func detach() -> void
func on_snapshot_taken(snapshot: ResultSnapshot) -> void
func on_call_made(ticks_left: int, burst_state: int) -> void
class_name DevLogs extends RefCounted
var launch_id: int
var build_hash: String
var run_sink: JsonlFileSink
var gesture_sink: JsonlFileSink

# src/root/battle_wrapper.gd (ADR-0001 signature extended)
func attach(battle: Battle, reduce_motion: bool, dev_logs: DevLogs = null) -> bool

# tests/bots/: Bot (between(i)), ScriptBot, CommandStep, GestureStep; tests/helpers/inert_hero_sim.gd
```

`RunLog.on_snapshot_taken` and `on_call_made` are called through HudLogic's injected Callables, not signals, so WIRE-8's naming rule does not apply to them. Names are provisional until ADR-0007's NAME lints run (QQ-16); new global names: `ChipWindow`, `PinGeometry`, `JsonlFileSink`, `RunLog`, `DevLogs`, `ResultSnapshot`, `CommandStep`, `GestureStep`, `Bot`, `ScriptBot`, `InertHeroSim`.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must change Tower and Hero battle state only through `build`, `upgrade`, `pin`, `burst` (and Flow's through `start_wave`, `call_early`, `pause`, `resume`); input classes and bots must never write a sim field or call a tick entry.
- Every command must start with the injected `between_ticks()` check (`fatal` and `HALTED` on failure), then `halted()`, then Decision 4's order.
- Must read every stat a command needs, with `halted()` after each read, before the first mutation; must call `is_tower` and `level_count` before any read with an untrusted ID or level.
- A refusal must change nothing and emit nothing; must emit `gold_changed` only on a change; must check `halted()` after every emit.
- Result enums must put `OK = 0` first, write every value, never renumber; a new check takes the next number.
- Must never create a `ReadContext` inside a command or a read; TowerSim reuses `_cost_ctx`.
- Must store every sim position as `float`; `Vector2` arguments are converted on entry and query results built on return; HeroInput must compute aim and ghost in `float` scalars.
- Gold must be written only by `build`, `upgrade`, `on_enemy_killed`, `on_wave_called_early`; both listeners must return at once when `halted()`.
- The early-call bonus must be `to_ticks(seconds_left) / _rate_ticks` in `int`.
- TowerInput must ignore every tap while `halted()`; `drag_cancelled` and `became_idle` listeners must never issue a command.
- `chip_state()` must be read in the handler or frame and never kept; `ChipWindow` durations are `const`, never catalogue values.
- Input-class listeners must be named `_on_<signal>` and connected only in `BattleWrapper._connect_signals()`, undone in `detach()`; each input class's `detach()` must unregister its discs and drop every reference.
- Bots must call only the six gameplay commands and Decision 7's reads, and must record every result code.
- `RunLog`, `GestureLog`, `JsonlFileSink` and `DevLogs` must exist only in debug builds; a sink failure must call `dev_error` once and never `fatal`; no record may contain a `Vector2`.
- HudLogic must call `snapshot_taken` and `call_made` only after `is_valid()`.
- Fakes and test subclasses overriding typed methods must `return` explicitly (4.7).

## Alternatives Considered

### Alternative 1: Input halves as `Node`s with their own `_process`
- **Description**: TowerInput and HeroInput extend `Node`, run their own `_process` for the chip clock and the hero centre.
- **Pros**: Familiar Godot shape.
- **Cons**: Breaks ADR-0004 Decision 5 (one `_process` in the battle subtree; sibling order unsourced); tests need a scene tree.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Contradicts the registry's `engine_time_in_sim` and `frame_order` stances.

### Alternative 2: A single `Battle.command(cmd, args) -> int` dispatcher
- **Description**: One string-keyed entry point for all callers and bots.
- **Pros**: One place to log and check between ticks.
- **Cons**: String dispatch is not parser-checked; loses typed enums; a second API to keep in step with the GDDs.
- **Estimated Effort**: Slightly less for logging, more for tests.
- **Rejection Reason**: The registry bans string Callables and prefers parse-time names; the injected check gives the same guarantee.

### Alternative 3: Debug-only between-ticks check
- **Description**: Check `between_ticks()` only when `OS.is_debug_build()`.
- **Pros**: Zero release cost.
- **Cons**: Sim code may not read `OS`; a release defect would desync silently; the cost saved is one call per command.
- **Estimated Effort**: Same.
- **Rejection Reason**: Architecture Principle 5 (fail loudly in every build) and the sim's no-`OS` rule.

### Alternative 4: `HeroSim.cooldown_total()`
- **Description**: HeroSim stores the tick length the current cooldown began with; the HUD divides by it.
- **Pros**: Exact wedge; no per-frame accessor read in the HUD.
- **Cons**: Stores a stat-derived value for later display, which the registry's `cached_stat_value` forbids; contradicts ADR-0005 Decision 7, which already names the HUD's per-frame `COOLDOWN` read.
- **Estimated Effort**: Less.
- **Rejection Reason**: Would supersede an ADR-0005 stance for a cosmetic gain. Revisit if a Vertical Slice modifier makes the wedge jump.

### Alternative 5: Float-pair command arguments `pin(x, y)`
- **Description**: Commands take two `float`s so bots keep 64-bit positions.
- **Pros**: No 32-bit rounding on bot positions.
- **Cons**: HeroInput still converts from `Vector2` payloads; the GDD's `clamp_pin` and criteria are written for `Vector2` in and out; two shapes for one command in tests.
- **Estimated Effort**: Similar.
- **Rejection Reason**: Equivalence compares like with like only if both routes pass the same type; the margins already absorb the rounding.

### Alternative 6: One merged dev log file
- **Description**: Run and gesture records in `user://dev_log.jsonl` with a `kind` field.
- **Pros**: One file to send.
- **Cons**: Gesture records come per press, run records per attempt; the phone-test analysis and the balance analysis read different records; one failure stops both.
- **Estimated Effort**: Same.
- **Rejection Reason**: Separate files keep each consumer simple; `launch_id` joins them when needed.

### Alternative 7: RunLog connects to `wave_called_early` (W5)
- **Description**: The log listens to Flow's W5 directly for call records.
- **Pros**: The log needs no HUD hook; bot calls would also be logged.
- **Cons**: W5 is a sim-to-sim wiring signal, not on ADR-0006's view allowlist; adding a wrapper listener changes the listener-count contract.
- **Estimated Effort**: Less code, more contract change.
- **Rejection Reason**: The HUD is the only human caller and already feeds the log its snapshot.

## Consequences

### Positive
- One door: player, HUD, bots and tests reach the sim through the same eight typed commands, so bot balance gates measure the shipped rules.
- Refusals are data, not errors: a bot's bad ID gets `BAD_TOWER`, never the fatal screen.
- The equivalence and absent tests turn Input Rule 11 and Hero Rule 1 into CI checks.
- Human telemetry exists from the first playable without touching sims.

### Negative
- Eleven new class names to keep collision-free (NAME lints).
- `slot_state` becomes five reads; GDD and architecture text change (cascade).
- A fatal on a command inside a tick ends a debug session that might have limped on.
- HudLogic carries two optional Callables for the log.

### Neutral
- TowerInput and HeroInput are testable without the scene tree, so most of their stories are Logic stories with fakes.
- `best_victims` adds a counter to every build's HeroSim state and digest.

## Risks

- **Callable reference semantics (ADR-0001 V1).** `between_ticks` is one more method Callable on Battle. Mitigation: same rollback as `halted()`.
- **`user://` unreachable on Android (V3).** Mitigation: desktop MVP first; a share action later.
- **Enum renumbering by a later edit.** Mitigation: explicit values; baselines store ints, so a renumber fails the baseline compare at once.
- **`ChipState` kept past the frame by a view.** Mitigation: Implementation Guidelines; review; the instance holds values only, so a kept one is stale, never unsafe.
- **Policy bots drift from the Python table.** Mitigation: the Hero GDD names the script as the tie-breaker; bot stories cite it.
- **A test swaps `battle.hero_sim` in production code by copy.** Mitigation: lint TEST scope; `InertHeroSim` lives only in `tests/helpers/`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| tower-system.md | TR-tower-001: TowerSim (builder-made, headless) holds gold, slots, towers and the tick; TowerInput (wrapper-made, absent headless) changes state only through upgrade | Decision 1 (table, door rule), Decision 8 |
| tower-system.md | TR-tower-002: build and upgrade are the only mutation API, run between ticks and return a typed result enum in fixed check order | Decisions 2, 3, 4 |
| tower-system.md | TR-tower-008: gold is one non-negative int owned by TowerSim, fed by starting_gold, enemy_killed and wave_called_early; frozen once halted | Decision 6 |
| tower-system.md | TR-tower-009: early-call bonus is to_ticks(seconds_left) div to_ticks(rate) | Decision 6 |
| hero-system.md | TR-hero-001: HeroSim (headless) and HeroInput (wrapper-only), which changes state only through pin and burst | Decision 1, Decision 8 |
| hero-system.md | TR-hero-002: pin and burst run between ticks, ordered enum codes, state before geometry, a refusal mutates nothing | Decisions 2, 3, 4, 5 |
| hero-system.md | TR-hero-009: read-only queries and per-run counters for HUD, bots, logs and Stage Progression | Decision 7 (reads, counters, `state_fields`) |
| hero-system.md | TR-hero-012: resolver-driven and direct-command scripts give tick-identical HeroSim state; never-pinned equals HeroSim-absent | Decision 9 |
| hero-system.md | TR-hero-015: burst_button_centre() owned by the HUD, read once by HeroInput at registration, injectable by tests | Decision 8 (value argument to `attach`) |
| battle-hud.md | TR-hud-013: debug builds append JSON lines to user://run_log.jsonl through an injectable sink; failure non-fatal; release never writes | Decision 10 |
| battle-hud.md | B10 reads requested by the HUD (`chip_state`, `wave_index`, `got_through_by_type`) and the cooldown total; Rule 15 snapshot | Decisions 7 and 11 |
| input-gesture-resolver.md | Rule 11: bots call the commands; one equivalence test keeps the intent | Decision 9 |
| game-state-stage-flow.md | QQ-18: Start/Call command names and results (Rules 6, 9; edge cases) | Decision 3 |
| tower-system.md | TR-tower-011 (ADR-0008's): TowerInput ignores taps while halted | Decision 8 (`halted` injected) |

## Performance Implications
- **CPU**: Commands: a few per frame at most, each a handful of checks and one to three accessor reads; unmeasurable against the 16.7 ms frame. `best_victims`: at most 2,304 squared-distance tests once per burst release (about every 10 s). `ChipWindow.advance`: one add per frame. RunLog: a few lines per attempt, debug only.
- **Memory**: Per battle a few hundred bytes of slot arrays and counters; `kills_per_burst` and `best_victims` grow by one `int` per burst (about 11 per stage).
- **Load Time**: None. `JsonlFileSink.open` at boot in debug builds only.
- **Network**: None.

## Migration Plan

No code exists. On acceptance, apply the cascade edits (architecture.md B8, B9, B10, Module Ownership rows, QQ-18; ADR-0006 P4 consumers; Tower Rule 17, Battle HUD Rule 12 and Input Rule 11 wording) in one change, then write Tower and Hero stories against Key Interfaces. The Pillar 4 harness story switches its interim sink to `JsonlFileSink` with `user://gesture_log.jsonl`.

**Rollback plan**: Each decision is local to a few files. Enum values can only grow. If the between-ticks fatal proves too blunt, it becomes `dev_error` plus `HALTED` (no interface change). If the split itself fails (for example, chip timing must be sim state), a superseding ADR moves the chip into TowerSim with tick-counted time; commands and enums stay.

## Validation Criteria

1. Per command, a refusal test for each code in check order: whole recording log empty, `state_fields()` unchanged, spy read log exactly the reads before the refusal (Tower criteria, Hero criteria 1 to 24).
2. A spy that latches `fatal` on the cost read: `build` and `upgrade` return `HALTED`, gold and slots unchanged.
3. A command called from inside a test listener during `battle.tick`: `fatal` cause names the command, return `HALTED`, nothing mutated.
4. Gold: `on_enemy_killed(0)` and a 0 bonus emit nothing; a halted battle pays nothing; starter bonus examples 900, 863 and 107 ticks give 8, 7 and 0.
5. Equivalence (Hero 27) and never-pinned (Hero 28) pass on `CatalogueFactory.minimal()` and the starter stage.
6. `ScriptBot` runs twice on one `(fixture, stage, rng_seed, script)` give equal digests and result arrays (ADR-0007).
7. RunLog with a recording sink: one attempt line per WON or LOST, one call line per `CallResult.OK`, none for FATAL; a sink returning `false` gives exactly one `dev_error` and play continues; in a release export no file is created (manual check, V2).
8. TowerInput with a `FakeResolver`: a tap reaches `slot_tapped`; chip commit window 200 to 1500 ms; taps ignored while halted; `is_chip_open()` matches `chip_state().open`.
9. Weakref test (ADR-0001) passes with TowerInput, HeroInput and RunLog attached and detached.

The decision is wrong if a bot needs a mutation path the commands lack, or the equivalence test cannot be made to pass without a test-only branch in production code.

## Related

- Depends on ADR-0004, ADR-0008, ADR-0009; binding ADR-0001, ADR-0002, ADR-0005, ADR-0006, ADR-0007. Enables ADR-0011.
- Settles open items: ADR-0004 item 15 (between-ticks enforcement), ADR-0006 Decision 6 (snapshot class), ADR-0008 Decision 9 items 1 to 3 and choice 7, ADR-0009's float-position constraint for HeroSim and TowerSim, `architecture.md` QQ-18 and B10.
- GDDs: `design/gdd/tower-system.md` (Rules 5 to 8, 14 to 17), `design/gdd/hero-system.md` (Rules 1 to 3, 6, 11 to 16; criteria 27, 28), `design/gdd/battle-hud.md` (Rules 7, 9, 12, 15, 19), `design/gdd/input-gesture-resolver.md` (Rules 11, 13), `design/gdd/game-state-stage-flow.md` (Rules 6, 9).
- Code (once written): `src/feature/tower/`, `src/feature/hero/`, `src/presentation/tower/`, `src/presentation/hero/`, `src/presentation/dev/`, `src/root/dev_logs.gd`, `tests/bots/`.
