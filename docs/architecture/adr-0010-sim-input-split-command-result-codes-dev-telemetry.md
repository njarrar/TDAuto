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

This ADR stays Proposed until: (1) ADR-0004, ADR-0008 and ADR-0009 are Accepted, and ADR-0007 too, because Decision 9's battle runner and the recording log come from it; (2) the before-acceptance verification items (V1, the V2 debug half, V3 desktop, V4) have recorded results in `docs/engine-reference/godot/current-best-practices.md`; (3) MET: the user confirms the autonomous choices in Decision 12 (confirmed by the user, 2026-11-04, as recommended, choices 1 to 16). The after-acceptance items (the V2 release half, V3 phone, Validation Criteria) do not hold acceptance.

Verification progress, 2026-11-04 (macOS arm64, headless, Godot 4.7.2 editor binary; `docs/engine-reference/godot/verification-results.md`, standing in for `current-best-practices.md` for this run): V1, the V2 debug half and V4 are RECORDED and take no branch; the V3 desktop path is recorded from the headless run. Still open before acceptance: the V3 desktop windowed run on the Mac (write one line, find the file).

Phone checks (user instruction, 2026-11-04): phone testing is set aside for now, and the future device is an iPhone. The V2 release half follows ADR-0001 V4, which moved after acceptance (iOS release export on the iPhone, Xcode console). V3 phone runs on the iPhone after acceptance. A phone result that contradicts this ADR reopens it before the next story in its area closes. Edit from this run: the `InertHeroSim` rule (Decision 9) now names lint INIT-1, because ADR-0009 V7 showed the engine does not enforce `super(...)`.

Amended 2026-11-05 after /architecture-review. (Decision 8: burst button centre re-read on inset change. Decision 11: per-source damage in `ResultSnapshot`. Amends row: the ADR-0004 `Time.*` exception for `dev_logs.gd`.)

**Reopen trigger.** If a bot needs a mutation path the eight commands lack, or the equivalence test needs a test-only branch in production code, this ADR is amended before the next Tower or Hero story closes. Owner: technical-director.

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate), godot-specialist (engine check). Authored with the /architecture-decision flow in autonomous mode. TD-ADR returned CONCERNS (T1 to T10) and the engine check returned three blocking findings (E1 to E3) plus minor notes; the parent chose "Revise flagged items" and all are applied in this revision (2026-11-04).

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
| **Post-Cutoff APIs Used** | `FileAccess.store_string` returning `bool` (4.4, sourced). 4.7 typed-return override rule: it binds fakes that override `pin()`, `burst()`, `build()` or `upgrade()`, which must return an enum value (sourced; the enum case is V4) |
| **Verification Required** | V1 to V4 below |

### Verification items

Owner: godot-specialist writes the scripts; the user runs them on 4.7.2; results go into `current-best-practices.md`. "Expected" is not a source.

**Before acceptance** (standalone scripts, none needs a story: V1, V2 and V4 in `prototypes/adr-checks/`; V3 desktop in `prototypes/adr-0010-checks/`):

- **V1. File append (reuses ADR-0008 V8; one headless run closes both).** `WRITE` truncates; `READ_WRITE` fails on a missing file; `seek_end()` then `store_string()` appends; `flush()` writes through; `store_string` returns `bool`; `FileAccess.get_open_error()` after a failed open. Branch: if `READ_WRITE` truncates, the sink rewrites from memory at each flush.
  - Result (2026-11-04, macOS arm64, headless): as ADR-0008 V8, plus `FileAccess.get_open_error()` = 7 (ERR_FILE_NOT_FOUND) after a failed open; see docs/engine-reference/godot/verification-results.md.
- **V2. Debug flag (reuses ADR-0008 V7).** `OS.is_debug_build()` is true in an editor run (headless script). The release half is ADR-0001 V4's spike result, recorded here; after acceptance, on the iPhone. Branch, decided now: if a release export reports true, `DevLogs` creation moves behind a custom export feature tag `dev_logs` tested with `OS.has_feature("dev_logs")`, set only in debug presets.
  - Result (2026-11-04, macOS arm64, headless): debug half: true in the editor run. The release half waits on ADR-0001 V4; see docs/engine-reference/godot/verification-results.md.
- **V3 (desktop). Where `user://` lands.** NOT SOURCEABLE in the pinned reference: a standalone debug run (`godot --path prototypes/adr-0010-checks`) writes one line and prints `OS.get_user_data_dir()`; the user finds the file on the desktop OS used for MVP, with `application/config/use_custom_user_dir` at its default. Owner: the user.
  - Result (2026-11-04, macOS arm64, headless): the headless run recorded `OS.get_user_data_dir()` on macOS as `/Users/<user>/Library/Application Support/Godot/app_userdata/<project>`. The windowed write-and-find step is still to run; see docs/engine-reference/godot/verification-results.md.
- **V4. Enums, standalone.** NEEDS VERIFICATION: `enum E { OK = 0, A = 1, C = 3, B = 2 }` (declaration order differs from values) parses; `typeof()` of a value returned from `-> E` is `TYPE_INT`; `E.find_key(2)` returns `"B"`; an enum-returning override needs an explicit enum `return` (`return null` fails); `PinGeometry` returning `HeroSim.PinResult` while `HeroSim` holds a `PinGeometry` (cyclic `class_name` reference) parses and runs. Branch: names come from a `const` table; the shared enums move to a const-only class `HeroResults`.
  - Result (2026-11-04, macOS arm64, headless): all pass: `typeof()` is TYPE_INT; `E.find_key(2)` is "B"; `keys()` follows declaration order (OK, A, C, B) while values are 0, 1, 3, 2, so `keys()[v]` would give the wrong name (use `find_key`); an override with no `return` or with `return null` does not load; the PinGeometry/HeroSim cycle parses and runs. No branch; see docs/engine-reference/godot/verification-results.md.

**After acceptance:**

- **V3 (Android).** Same script on the first phone build; whether `adb exec-out run-as <pkg>` works on Godot's debug APK (debuggable flag unconfirmed). Android-only: deferred until an Android device is available; iPhone run covers the iOS equivalent where one exists: on the iPhone, run the same script from an iOS debug export and find the file in the app container that Xcode's Devices window downloads. Owner: the user. Branch: Mobile Platform work adds a dev "share log" action; desktop MVP is unaffected.
- Validation Criteria 1 to 9, in the Tower, Hero and HUD stories.

Not relied on: `Dictionary` order, sibling `_process` order, engine timers.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (between-ticks rule, `between_ticks()`, `ticks_run()`, frame order, `to_ticks`, float policy), ADR-0008 (resolver API, registry, `GestureLog`), ADR-0009 (float scalar sim positions, Combat helpers, `targets()`). Binding, also Proposed: ADR-0001 (Builder, injected method Callables, `halted()`, `fatal`, `dev_error`, retry teardown), ADR-0002 (records, `PackedFloat64Array` geometry), ADR-0005 (accessor, `is_tower`, `level_count`, read before mutate), ADR-0006 (signal names, payloads, allowlist, `StageResult`, listener rules), ADR-0007 (battle runner, digest, recording fakes, lint) |
| **Enables** | ADR-0011 (views read the queries fixed here). Every Tower, Hero, Battle HUD and bot story |
| **Blocks** | Every Tower System, Hero System and Battle HUD story; the bot balance gates (Hero Deferred criteria); the Pillar 4 gesture-log harness story's sink choice |
| **Amends** | ADR-0006 Decision 5 table: TowerInput joins P1 and P4, RunLog (development builds only) joins P1, P4, P6, P7, and P4 becomes required (Decision 8). ADR-0001: `BattleWrapper.attach` gains optional `dev_logs`. ADR-0004 Decision 5: the between-ticks check runs in every build, not only development builds (Decision 2). ADR-0008 Decision 8: fills its delegated `chip_open` and sink slots. ADR-0004 Implementation Guidelines: `Time.get_unix_time_from_system` in `src/root/dev_logs.gd` joins the `Time.*` exceptions (Decision 10; lint TIME-3 already allows it). `architecture.md` B9: new `between_ticks` row; `halted` also injected into the input classes. All as exact edits in the cascade notes |
| **Ordering Note** | Write after ADR-0009. ADR-0011 follows. Accept only after ADR-0004, ADR-0007, ADR-0008 and ADR-0009 are Accepted. The amendments above and the GDD edits land with acceptance |

## Context

### Problem Statement

Tower and Hero need real time (the upgrade chip, the aim drag) and the resolver, yet the battle must run headless and deterministic. Each GDD splits its system in two and leaves to this ADR where the halves sit, the one door for bots and humans, command results, gold ownership, HUD reads, the bot script and the human run log. Tower and Hero stories wait on it (architecture.md Priority).

### Current State

No code exists. `architecture.md` B8 sketches the enums; ADR-0004, 0006, 0008 and 0009 hand open items here. Tower Rule 17 puts `chip_state()` on TowerInput while B8 and B10 put it on TowerSim; B8's `Vector2` positions meet ADR-0009's float rule.

### Constraints

- Sims are `RefCounted`, built only by `BattleBuilder.build`, and never read a node, `Engine`, `Time`, `OS`, a timer or `await` (ADR-0001 B4), so a sim cannot test `OS.is_debug_build()`.
- Registry stances bind: `command_inside_tick`, `command_from_sim_or_cancel_listener`, `sim_position_representation`, `cached_stat_value`, `emit_before_commit`, `connection_outside_builder_or_attach`, `autoload_singleton`, `mutable_static_var`, `injected_and_connected_callables`.
- Read before mutate, `is_tower`/`level_count` first, `halted()` after every read and emit (ADR-0005 Decision 7, ADR-0006 Decision 1).
- Solo part-time developer: few classes, no framework.

### Requirements

The ten TRs in GDD Requirements Addressed, plus: no measurable tick cost (commands run a few times per frame at most).

## Decision

### 1. The split: two sims in Battle, three input classes in the wrapper

| Class | Folder | Built by | Holds |
|---|---|---|---|
| `TowerSim` | `src/feature/tower/` | `BattleBuilder.build` | Gold, slot arrays, per-slot `ReadContext`s, `cooldown_left`, `slows_applied`, `build`, `upgrade`, `tick` |
| `HeroSim` | `src/feature/hero/` | `BattleBuilder.build` | Position, pin target, walk, pin and burst state, timers, aim point, counters, hero and burst contexts, `pin`, `burst`, `tick` |
| `PinGeometry` (pure) | `src/feature/hero/` | HeroSim and HeroInput, one each | Pin rect and active-hand shapes as floats |
| `TowerInput` | `src/presentation/tower/` | `BattleWrapper.attach` | Slot, tower and chip disc ids; one `ChipWindow`; `slot_tapped`, `tower_inspected` |
| `ChipWindow` (pure) | `src/presentation/tower/` | TowerInput | Open slot, elapsed ms |
| `HeroInput` | `src/presentation/hero/` | `BattleWrapper.attach` | Hero, button and sink disc ids; aim state; aim point; ghost; digit |

All six extend `RefCounted`. The last three never exist headless unless a test makes them.

- TowerInput and HeroInput are not nodes, so tests build them on a headless battle with `battle.resolver` (ADR-0008 Builder step 2) or a `FakeResolver`.
- TowerInput changes battle state only through `tower_sim.upgrade`; HeroInput only through `hero_sim.pin` and `hero_sim.burst`; HudLogic only through `tower_sim.build`, `flow.start_wave`, `flow.call_early`. No input class writes a sim field or calls a tick entry.
- The wrapper builds them in `attach` after HudLogic, connects their listeners in `_connect_signals()`, and in `detach()` calls each one's `detach()` (unregister discs, drop references); the ADR-0001 weakref test covers them. `tower_input.advance(ms)` runs in frame step 1, `hero_input.update()` first in step 4 (ADR-0004 Decision 5).

### 2. Eight commands, checked between ticks

The complete MVP command set: `TowerSim.build`, `TowerSim.upgrade`, `HeroSim.pin`, `HeroSim.burst`, `Flow.start_wave`, `Flow.call_early`, `Flow.pause`, `Flow.resume`. This is ADR-0007 WIRE-9's list unchanged; no new command is added.

**Enforcement.** The Builder injects `between_ticks: Callable` (`battle.between_ticks`, a method Callable like `halted`) into TowerSim, HeroSim and Flow. Every command's first statement is:

```gdscript
if not _between_ticks.call():
    _fatal.call("command inside tick: TowerSim.build")
    return BuildResult.HALTED
```

`pause()` and `resume()` return after the `fatal` call. `fatal` makes `halted()` true, so `HALTED` is the honest return. It costs one call per command. This closes ADR-0004's "ADR-0010 decides enforcement" (item 15) and widens ADR-0004 Decision 5's "in development builds" to every build (cascade).

Why `fatal`, in every build:

- The legitimate callers are all outside a tick: gesture listeners in `flush()` at frame step 0, `bot.between(i)` before each runner tick, and `Flow.pause`/`resume` from engine callbacks outside `_process`. The registry already forbids commands from sim listeners and from `drag_cancelled`/`became_idle` listeners. So a mid-tick call can only come from a wiring defect.
- Architecture Principle 5: no fallbacks in any build, fail loudly once. A sim cannot read `OS.is_debug_build()` anyway.
- A refusal code would silently drop a player's tap in release and hide the defect, though it would keep determinism just as well.

**Assumption (named).** Lifecycle notifications (`lifecycle_paused` to `Flow.pause`, the Paused tap to `Flow.resume`) never arrive while `Battle.tick` runs; if one did, backgrounding the app would latch a release fatal. ADR-0003 SP10 and SP11 and ADR-0004 V7 record notification timing; the spike kit also logs `battle.between_ticks()` inside the notification handler (cascade note for the kit README). If it is ever false there, `pause()` alone switches to deferring the call to the next frame step 0, by amendment.

### 3. Result enums

Rules: `OK = 0` first; every value written explicitly; declaration order after `OK` is the GDD's check order; values are never renumbered or reused; a new check takes the next unused number and is declared in its check position, so values stop following declaration order. Logs and bot results store the `int`; names always come from `Enum.find_key(v)`, never `keys()[v]` (V4). Bots keep results in `PackedInt32Array`; code that puts an `int` back into an enum-typed variable casts it explicitly (`as`), to avoid `INT_AS_ENUM_WITHOUT_CAST`.

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

`StartResult.NOT_BUILD` is Game State's "a second tap finds no Build and is ignored"; `CallResult.NOTHING_LEFT` is "a call at 0 is ignored with no signal". `pause()` and `resume()` keep `-> void` (bots never pause; Flow's own state rules decide). `PinGeometry.is_valid` returns `HeroSim.PinResult` (`OK`, `OUT_OF_BOUNDS` or `BUTTON_ZONE`); the cyclic `class_name` reference is in V4, with a const-only `HeroResults` class as its branch.

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

**Handling results in input code.** HudLogic's arc (Battle HUD Rule 7) and TowerInput's chip (Tower Rule 8): `OK` closes; `NO_GOLD` stays open; `HALTED` closes; anything else closes and calls `dev_error` with the enum name. HeroInput: `OK` and `HALTED` are normal; anything else is a `dev_error` (Hero Rule 13). Bots record every result (Decision 9).

### 5. Positions at the command boundary

- `pin(pos: Vector2)` and `burst(aim_point: Vector2)` keep `Vector2` arguments, as ADR-0009 allows: after Decision 4 steps 0 and 1 the body reads `var x: float = pos.x`, `var y: float = pos.y`; nothing else touches `pos`. Every stored position (hero position, walk origin, pin target, aim point) is a `float` pair; slot origins are read from `StageRecord.slot_positions` (`PackedFloat64Array`, ADR-0002), never copied into `Vector2`.
- Why `Vector2`, not `(x, y)`: Alternative 5.
- HeroInput computes the aim point, the reach clamp and the ghost in `float` scalars (finger plus offset, field clamp, reach clamp to `reach - 0.01`) and builds a `Vector2` only for the command call, so no `Vector2` operator decides what a command receives.
- Queries that return positions return a new `Vector2` built from the floats (`position()`, `pin_target()`, `slot_position(i)`). They are view and bot reads; sim code never calls them. The registry entry `sim_position_representation` gains "query returns for views and bots" in its allowed list (cascade).

### 6. Gold

- `TowerSim._gold: int` is the only gold. Set once at construction from `StageRecord.starting_gold` (a direct read, ADR-0005 Decision 8); no `gold_changed` at construction; the HUD reads `gold()` in `attach`.
- Faucets: `on_enemy_killed(bounty)` (W2) and `on_wave_called_early(seconds_left)` (W5). Sinks: `build`, `upgrade`. Nothing else writes it. No faucet adds a negative amount; a sink checks `gold >= cost` first, so gold never goes below 0.
- Both listeners return at once if `halted()` (gold freezes; a fatal leak skips the reap anyway, ADR-0004), add nothing when the amount is 0, emit `gold_changed(gold)` only on a change, then check `halted()`.
- Early-call bonus (TR-tower-009): `_rate_ticks = to_ticks(stage.early_call_seconds_per_gold)` once at construction (structural field, not a stat; if below 1, `fatal("stage: early_call_seconds_per_gold under one tick")`, which ADR-0002's boot check already prevents for real data). The listener computes `maxi(0, to_ticks(seconds_left)) / _rate_ticks`, both `int` and non-negative, because `int / int` truncates toward zero; the `@warning_ignore("integer_division")` annotation sits on that statement only. Flow sends `seconds_left = intermission_left * dt`, and `to_ticks` returns `intermission_left` exactly for every value up to 600 s (ADR-0004 Validation 3 covers the round trip).
- The bonus reads no burst state and no Flow state (Flow Rule 9).

### 7. The read surface (B10 settled)

Read-only, allocation-free unless stated, safe from views, HUD, bots, logs and tests; only accessor reads can reach `fatal`.

| Owner | Reads |
|---|---|
| TowerSim | `gold() -> int`; `slot_count()`; `slot_tower(i) -> StringName` (`&""` empty); `slot_level(i)` (0 empty); `slot_cooldown_left(i)`; `slot_position(i) -> Vector2`; `slows_applied()`; `state_fields()` |
| HeroSim | `position()`, `pin_target()` (`hero_start` before a first pin) `-> Vector2`; `pin_state() -> PinState`; `burst_state() -> BurstState`; `cooldown_left()`; `hero_id()`, `burst_id() -> StringName`; counters; `state_fields()` |
| TowerInput | `chip_state() -> TowerInput.ChipState`; `is_chip_open() -> bool`; signals `slot_tapped(slot_index: int)`, `tower_inspected(slot_index: int)` |
| HeroInput | `aim_state() -> AimState`; `aim_point() -> Vector2`; `cooldown_digit() -> int` |

Flow, EnemyWave and Combat reads are B5, B7 and B6 unchanged.

- **`chip_state()` belongs to TowerInput** (Tower Rule 17 is right; B8 and B10 are corrected): the window is real time and lives in the wrapper. `ChipState` is an inner value class (`open`, `slot_index` (-1 closed), `elapsed_ms`, `level`), one reused instance; callers never keep it.
- **Slot reads are per field**, replacing B8's `slot_state() -> Array` and the GDD's `slot_state(slot_index)`: typed, no per-frame allocation. A bad `i` returns the empty value and calls `dev_error` once per TowerSim instance (a `_bad_index_reported` latch), never `fatal`. HeroSim has no indexed reads, so no such report.
- **Counters** (Hero Rule 16), updated only in `pin` and at release: `repins`, `bursts_fired`, `bursts_hit_0`, `bursts_hit_3`, `bursts_hit_5`, `burst_victims`, `burst_kills` (`int`); `kills_per_burst`, `kills_on_hit_3`, `best_victims` (`PackedInt32Array` copies). `best_victims` (most `targets()` a burst-radius disc centred on an enemy holds at release) is computed in every build, since a sim cannot test for debug; at most 48 x 48 tests per release.
- **Cooldown total**: HudLogic computes `to_ticks(stat_float(burst_ctx, StatKeys.COOLDOWN))` as ADR-0005 Decision 7 says, with a burst context made in `attach` from `hero_sim.burst_id()` and `halted()` after the read. `cooldown_total()` was rejected (Alternative 4).
- **`wave_index()`, `got_through_by_type()`** ratified as ADR-0009 defined them; readers look types up in Wave-record order and never iterate the `Dictionary`.
- **`state_fields()`**: every field as JSON-native values for ADR-0007's `digest`, the equivalence test and the run log; allocates; no gameplay code calls it.

### 8. Input-side bindings

**TowerInput** (Tower Rules 8, 17; Battle HUD Rule 9). `attach(resolver, tower_sim, accessor, halted: Callable, dev_error: Callable)`.

- Registers one TAP disc per slot (priority 200, slot radius per Input GDD). Listens to `tower_sim.tower_built` (P4): disables that slot's disc and registers the tower's TAP disc at the same centre. This amends ADR-0006's table: TowerInput joins P1 and P4, and P4's `required_after_attach` becomes yes. Yes is correct because only the wrapper test checks that column, after `attach`, where TowerInput always exists; the headless wiring test is unaffected, since TowerInput is never built headless. RunLog joins P1, P4, P6 and P7 as a development-only consumer that changes no required flag.
- No position conversion (ADR-0008 open item 3): `upgrade(slot_index)` takes no position, and every hit test is a resolver disc.
- `_on_tapped(best_tap, p)`: returns at once if `halted.call()` (TR-tower-011; **`halted()` is now injected into TowerInput** by the wrapper, B9 cascade). Empty slot: emits `slot_tapped(slot_index)`. Tower below `accessor.level_count(def_id)`: opens or commits the chip per Rule 8's table. Tower at its last level: emits `tower_inspected(slot_index)`.
- `ChipWindow`: `open(slot_index)`, `close()`, `advance(ms: float)` (ignores non-finite or negative ms), `is_open()`, `slot()`, `elapsed_ms()`, `can_commit() -> bool` (`200 <= elapsed < 1500`). `MIN_COMMIT_MS := 200.0` and `WINDOW_MS := 1500.0` are `const` presentation constants (Data Rule 1). `TowerInput.advance(ms)` calls it and, on expiry, unregisters the chip disc (registry calls are legal at any time, ADR-0008).
- `_on_pressed`: applies Rule 8's close rules. `_on_phase_changed`: closes on PAUSED, WON, LOST, FATAL.
- `GestureLog`'s `chip_open` Callable (ADR-0008 Decision 8) is wired by the wrapper as `tower_input.is_chip_open`.

**HeroInput** (Hero Rules 11 to 15). `attach(resolver, hero_sim, accessor, halted: Callable, in_build: Callable, left_handed: bool, stage: StageRecord, burst_button_centre: Vector2, dev_error: Callable)`.

- `burst_button_centre` is a value, read by the wrapper from `hud_logic.burst_button_centre()` and passed in; tests pass any point (TR-hero-015). It sets the button and sink disc centres and the cancel ring's 64 and 48.
- **Re-read on inset change** (TR-hud-018; ADR-0003 Decisions 5 and 7; amended 2026-11-05). Insets can move the button mid-battle. On `display_changed` (A2) the wrapper calls `hud_logic.set_insets(insets)`, then re-reads `hud_logic.burst_button_centre()` and calls `hero_input.set_button_centre(c: Vector2)`, which moves the button and sink discs with `resolver.set_centre` (legal at any time, ADR-0008) and the cancel ring. An aim in progress keeps its state; the next press uses the new discs.
- Registers hero (DRAG 200, r 56), button (DRAG 100, r 48), sink (TAP 400, r 48). `update()` (frame step 4) calls `set_centre` for the hero from `position()`, re-clamps the aim and refreshes the digit.
- Reads Burst `REACH` through its own burst context (made in `attach`) when it clamps an aim, with `halted()` after the read; a halted read ends the aim.
- Issues `pin` on `drag_ended` of a hero drag, with `PinGeometry.clamp_point` of the offset finger; issues `burst` on `drag_ended` of a Live aim. `drag_cancelled` and `became_idle` clear state and never issue a command.

### 9. Bots and equivalence (TR-hero-012, Input Rule 11)

**One door.** A bot is an object whose `between(i: int) -> void` is passed to ADR-0007's `battle_runner.run(battle, ticks, between)`. It may call only the six gameplay commands (bots never pause) and Decision 7's reads, plus `PinGeometry` and accessor reads; it never writes a field, connects a signal or calls a tick entry. Bots live in `tests/bots/`, exported only by the dev preset ADR-0004 V5's phone bot-run entry needs (ADR-0007 owns presets).

**Script format.** `CommandStep` (`tests/bots/command_step.gd`, values only): `at_tick: int`, `command: StringName` (`&"build"`, `&"upgrade"`, `&"pin"`, `&"burst"`, `&"start_wave"`, `&"call_early"`), `slot_index: int = -1`, `tower_id: StringName = &""`, `x`, `y: float` (pin and burst, passed as `Vector2(x, y)`). `ScriptBot` keeps an `Array[CommandStep]` sorted by `at_tick` and a cursor; each `between` call issues every unfired step with `at_tick <= battle.ticks_run()` (ADR-0004 Decision 4), in array order, and appends the result to `results: PackedInt32Array`. Build-phase steps and `start_wave` all sit at tick 0, since Build runs no ticks. The baseline text form is one JSON object per step. Policy bots (Hero Simulated results) extend the same `Bot` base; their parameters are `const` in the bot file.

**Equivalence** (Hero criterion 27). `GestureStep` (`at_tick`, `call`: press, move, release or cancel_pointer, `pointer`, `x`, `y`). Route A: a headless battle, a real HeroInput on `battle.resolver` with a test `burst_button_centre`; per runner step, that tick's gesture calls, then the tick, then `hero_input.update()`. Route B: the same inputs with a `ScriptBot` carrying the positions route A computed (fingers chosen so no clamp moves them). After every tick, `hero_sim.state_fields()`, the counters and a recording log of HeroSim's signals are equal. TowerInput's wiring is proven with a `FakeResolver` (Tower Rule 17).

**Never pinned equals absent** (Hero criterion 28). "Absent" is `InertHeroSim extends HeroSim` (`tests/helpers/`): its `tick() -> void` override does nothing (a `void` override needs no `return`), and its `_init` forwards HeroSim's arguments with `super(...)` (the engine does not check this, ADR-0009 V7; lint INIT-1 does). No instance holds a connection: the Builder connects no signal to or from HeroSim (ADR-0006 W1 to W5 skip it) and only injects Callables, and its view signals connect only in `BattleWrapper.attach`, which this test never runs. So `TestBattles.with_inert_hero(...)` builds with `BattleBuilder.build`, constructs `InertHeroSim` from the battle's public members as the Builder builds HeroSim's arguments, and assigns `battle.hero_sim` before the first tick; the real instance is freed. A Builder option that builds InertHeroSim in place was rejected as a production branch for a test; if HeroSim ever gains a Builder connection, the listener-count test shows it and the helper is revisited. Both runs keep per-tick lives, gold, roster, slots, the `deliver` and `attack_fired` logs and the spy read log equal; the real HeroSim's `state_fields()` keep their initial values.

### 10. Development telemetry: the run log

**Files and sink.** Two files, one sink class: `user://run_log.jsonl` and `user://gesture_log.jsonl` (ADR-0008's `GestureLog`; settles its choice 7: no merge). `JsonlFileSink` (`src/presentation/dev/jsonl_file_sink.gd`, `RefCounted`) applies ADR-0008 V8: `static func open(path: String) -> JsonlFileSink` is null in release or on failure (`READ_WRITE` if the file exists, else `WRITE`; `seek_end()`; one handle); the caller reports a failed open once through `dev_error` with `FileAccess.get_open_error()`. `write_line(text: String) -> bool` stores `text + "\n"`, checks the `bool`, then `flush()`. `close()`.

**Session object.** In debug builds AppRoot makes one `DevLogs` (`src/root/dev_logs.gd`, `RefCounted`) at boot: `launch_id: int` (`int(Time.get_unix_time_from_system() * 1000.0)`, ADR-0004 V8's read), `build_hash: String` (`const BUILD_HASH` in `src/root/build_info.gd`, `"dev"` in the repo, stamped by the export script), `run_sink`, `gesture_sink`, `close()`. AppRoot calls `close()` on `NOTIFICATION_WM_CLOSE_REQUEST` and in its teardown, since a handle closes only when its sink is freed. It holds no battle object or Callable, so it may live for the session. `BattleWrapper.attach(battle, reduce_motion, dev_logs: DevLogs = null)`: with null, no log node is made.

**RunLog** (`src/presentation/dev/run_log.gd`, `extends Node`, made by `attach` only with `dev_logs`): `attach(battle, sink: Callable, launch_id: int, build_hash: String, dev_error: Callable)`, sink `dev_logs.run_sink.write_line` or an invalid `Callable()`; tests pass a recording fake.

- A view listener (ADR-0006 rule 2) of P1, P4, P6, P7; reads queries; no command, no sim write. It stamps `Time.get_ticks_msec()` for real seconds to first build, pin and burst (Paused included); `src/presentation/dev/` is outside the `engine_time_in_sim` lint (ADR-0008 cascade).
- **Attempt record**, per WON or LOST: HudLogic's injected `snapshot_taken` Callable passes the `ResultSnapshot` to `run_log.on_snapshot_taken`, so screen and log read one object (Rule 15). FATAL and quits write none (Rule 19).
- **Call record**, per `CallResult.OK`: HudLogic, the only human caller of `call_early`, reads `intermission_left` and `burst_state()` just before the call and on `OK` calls `call_made` (`run_log.on_call_made(ticks_left: int, burst_state: int)`). RunLog reads `flow.lives()` then and at the next `phase_changed` to INTERMISSION, WON or LOST, and writes `seconds_left`, `ticks_left`, burst state and lives lost.
- Fields, JSON-native, no `Vector2`: `kind`, `launch_id`, `build_hash`, `stage_id`, `rng_seed` (ADR-0004), `ticks_run`, then Rule 19's lists; `JSON.stringify(record, "", true, true)` (ADR-0002's form).
- **Never fatal.** An invalid sink or a `false` write calls `dev_error` once per RunLog and play goes on; later lines are still tried. HudLogic calls its two Callables (default `Callable()`) only after `is_valid()`.

### 11. The HUD result snapshot

`ResultSnapshot` (`src/presentation/hud/result_snapshot.gd`, `RefCounted`, values only, no signal) is built by HudLogic at the moment ADR-0006 Decision 6 fixed (first `advance` after `phase_changed(WON)` or `(LOST)`). Fields: `result: StageResult`; `stage_id: StringName`; `rng_seed: int`; `ticks_run: int`; `got_through: Dictionary` (a copy); `slows_applied: int`; `towers_built: int` (built slots counted from slot reads); `hero_pinned_ever: bool` (`pin_state() != UNPINNED`); `hero_share: float`; `dealt_by_source: Dictionary` (amended 2026-11-05, TR-hud-013: `StringName` source id to damage `float`, one entry per tower id built this battle in slot order, then the hero id and the burst id, each from `combat.dealt_by_id`; readers iterate in that stored order through `dealt_sources: Array[StringName]`, never the `Dictionary`); the per-kind totals (`dealt_by_kind`, three floats); the ten Hero counters (arrays copied). It references no sim object, so a view may keep it after the battle is dropped. The Next-try line (Battle HUD Rule 16) and the result rows read only it.

### 12. Choices made in autonomous mode

The complete list; each can be overturned (cascade section d):

Confirmed by the user, 2026-11-04, as recommended: choices 1 to 16, each as written below.

1. Between-ticks check in every build, `fatal` plus `HALTED` (Decision 2); widens ADR-0004 Decision 5.
2. Explicit enum values, names by `find_key` (Decision 3); `StartResult` and `CallResult` names and codes (QQ-18).
3. `chip_state()` on TowerInput, a reused inner `ChipState`; `GestureLog.chip_open` is `tower_input.is_chip_open` (Decisions 7, 8).
4. Per-field slot reads replace `slot_state` (rename in GDDs and `architecture.md`).
5. Cooldown total stays HUD-computed through the accessor; HeroSim gains `hero_id()` and `burst_id()` instead of `cooldown_total()`.
6. `best_victims` computed in every build.
7. `Vector2` command arguments, not `(x, y)` pairs; HeroInput computes in scalars (Decision 5).
8. Bot steps keyed by `ticks_run()` with a cursor; bots in `tests/bots/`, exported only by a dev preset.
9. "HeroSim absent" is a test-only `InertHeroSim` swapped in after build; no production branch.
10. Two log files, one sink class, held by a session `DevLogs` on AppRoot.
11. Call records come from HudLogic's injected `call_made` Callable (and the attempt record from `snapshot_taken`), not a W5 connection.
12. TowerInput listens to P4 `tower_built` to swap slot and tower discs, and P4 becomes required after attach (Decision 8).
13. `BattleWrapper.attach` gains an optional `dev_logs` argument (amends ADR-0001).
14. TowerInput and HeroInput are `RefCounted`, not `Node`, so they are testable headless.
15. `launch_id` from the session's unix-millisecond read; `build_hash` from a stamped `const`.
16. V2's branch: a `dev_logs` export feature tag if a release export reports a debug build.

### Architecture Diagram

```
 BattleBuilder.build (headless)               BattleWrapper.attach (absent headless)
 Battle                                        HudLogic   -> build, start_wave, call_early
   Flow --W5--> TowerSim <--W2-- EnemyWave     TowerInput -> upgrade   (ChipWindow, step 1)
   TowerSim: gold, slots, build, upgrade  <--  HeroInput  -> pin, burst (update(), step 4)
   HeroSim: pin, burst, counters          <--  RunLog, GestureLog (debug) -> JsonlFileSink
   resolver --G1..G8--> input classes          reads Decision 7; P1..P9 view listeners
   injected: halted, between_ticks, fatal, to_ticks, in_build, targets, dev_error
 bots (tests/bots): battle_runner.run -> between(i) -> the same six commands; reads only
```

### Key Interfaces

```gdscript
# src/feature/tower/tower_sim.gd
class_name TowerSim extends RefCounted          # enums BuildResult, UpgradeResult: Decision 3
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
# slot_count, slot_tower, slot_level, slot_cooldown_left, slot_position, slows_applied, state_fields: Decision 7

# src/feature/hero/hero_sim.gd
class_name HeroSim extends RefCounted           # enums PinResult, BurstResult: Decision 3
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
# position, pin_target, pin_state, burst_state, cooldown_left, hero_id, burst_id: Decision 7
# counters, Decision 7: repins, bursts_fired, bursts_hit_0, bursts_hit_3, bursts_hit_5,
# burst_victims, burst_kills -> int; kills_per_burst, kills_on_hit_3, best_victims -> PackedInt32Array (copies)
func state_fields() -> Dictionary

# src/feature/hero/pin_geometry.gd
class_name PinGeometry extends RefCounted
func _init(stage: StageRecord, left_handed: bool) -> void     # rect and active-hand shapes as floats
func is_valid(x: float, y: float) -> HeroSim.PinResult        # OK, OUT_OF_BOUNDS or BUTTON_ZONE
func clamp_point(fx: float, fy: float, hold_x: float, hold_y: float) -> Vector2   # clamp_pin; not clamp(), which shadows the global

# src/root/battle_wrapper.gd (amends ADR-0001)
func attach(battle: Battle, reduce_motion: bool, dev_logs: DevLogs = null) -> bool
# Flow commands and enums: Decision 3. TowerInput, ChipWindow, HeroInput: Decisions 7 and 8.
# JsonlFileSink, RunLog, DevLogs: Decision 10. Bots: tests/bots/ (Decision 9).
```

`RunLog.on_snapshot_taken` and `on_call_made` are reached through HudLogic's Callables, not signals, so WIRE-8 does not apply. Names are provisional until ADR-0007's NAME lints run (QQ-16); new global names: `ChipWindow`, `PinGeometry`, `JsonlFileSink`, `RunLog`, `DevLogs`, `ResultSnapshot`, `CommandStep`, `GestureStep`, `Bot`, `ScriptBot`, `InertHeroSim`.

### Implementation Guidelines

For `/create-control-manifest` and `/dev-story`:

- Must change Tower, Hero and Flow state only through the eight commands; input classes and bots must never write a sim field or call a tick entry.
- Every command must start with the `between_ticks()` check (`fatal`, then `HALTED`), then `halted()`, then Decision 4's order: lookups, all reads (each followed by `halted()`), then commit, then emits.
- A refusal must change nothing and emit nothing; `gold_changed` only on a change; `halted()` after every emit.
- Result enums: `OK = 0` first, every value explicit, never renumbered.
- Must never create a `ReadContext` in a command or a read.
- Sim positions must be `float`; `Vector2` arguments converted on entry; HeroInput computes aim and ghost in scalars.
- Gold must be written only by `build`, `upgrade`, `on_enemy_killed`, `on_wave_called_early`; the bonus is `int` tick division.
- TowerInput must ignore taps while `halted()`; `drag_cancelled`/`became_idle` listeners never issue a command; `chip_state()` is never kept.
- Input-class listeners are `_on_<signal>`, connected only in `BattleWrapper._connect_signals()`, undone in `detach()`, which also unregisters discs and drops references.
- Bots call only the six gameplay commands and Decision 7's reads, and record every result.
- Dev log classes exist only in debug builds; a sink failure calls `dev_error` once, never `fatal`; no record holds a `Vector2`; HudLogic calls its log Callables only after `is_valid()`.
- Test subclasses and fakes overriding typed methods must `return` explicitly (4.7).

## Alternatives Considered

Effort of each is within a story of the chosen approach.

### Alternative 1: Input halves as `Node`s with their own `_process`
- **Description / Pros / Cons**: familiar Godot shape; but breaks ADR-0004 Decision 5 (one `_process`; sibling order unsourced) and needs a scene tree in tests.
- **Rejection Reason**: Contradicts `engine_time_in_sim` and `frame_order`.

### Alternative 2: One `Battle.command(cmd, args) -> int` dispatcher
- **Description / Pros / Cons**: one place to log and check; but string dispatch is not parser-checked and loses typed enums.
- **Rejection Reason**: The registry prefers parse-time names; the injected check gives the same guarantee.

### Alternative 3a: Debug-only between-ticks check
- **Description / Pros / Cons**: zero release cost; but sims may not read `OS`, and a release wiring defect would pass unseen.
- **Rejection Reason**: The no-`OS` rule and Principle 5.

### Alternative 3b: A new refusal code (`IN_TICK`) plus `dev_error`, in every build
- **Description / Pros / Cons**: no fatal screen, determinism kept; but a code in six enums and the GDD tables, and in release it silently drops a player's tap while hiding the defect.
- **Rejection Reason**: Principle 5; the only cause is a wiring defect, which should stop the run.

### Alternative 4: `HeroSim.cooldown_total()`
- **Description / Pros / Cons**: exact wedge, no per-frame HUD read; but stores a stat-derived value (`cached_stat_value`) against ADR-0005 Decision 7.
- **Rejection Reason**: Supersedes an ADR-0005 stance for a cosmetic gain; revisit if a modifier makes the wedge jump.

### Alternative 5: Float-pair command arguments `pin(x, y)`
- **Description / Pros / Cons**: 64-bit bot positions; but HeroInput still converts, and the GDD's `clamp_pin` and criteria are written for `Vector2`.
- **Rejection Reason**: Equivalence compares like with like only if both routes pass one type; margins absorb the rounding.

### Alternative 6: One merged dev log file
- **Description / Pros / Cons**: one file to send; but different record rates and consumers, and one failure stops both.
- **Rejection Reason**: Separate files keep each consumer simple; `launch_id` joins them.

### Alternative 7: RunLog connects to `wave_called_early` (W5)
- **Description / Pros / Cons**: no HUD hook, bot calls logged too; but W5 is not on ADR-0006's view allowlist, so listening adds a key, while P1, P4, P6 and P7 are already on it.
- **Rejection Reason**: An allowlist key for a dev log is a contract change; the HUD is the only human caller and already feeds the log.

## Consequences

### Positive
- One door: player, HUD, bots and tests use the same eight typed commands, so bot gates measure the shipped rules.
- Refusals are data: a bot's bad ID gets `BAD_TOWER`, never the fatal screen.
- Input Rule 11 and Hero Rule 1 become CI checks; human telemetry exists from first playable without touching sims.

### Negative
- Eleven new class names (NAME lints); `slot_state` becomes five reads (cascade edits).
- A mid-tick command ends even a debug session; HudLogic carries two optional log Callables.

### Neutral
- Most input-class stories are Logic stories with fakes; `best_victims` joins every build's HeroSim state.

## Risks

- **Callable reference semantics (ADR-0001 V1).** `between_ticks` is one more method Callable on Battle. Mitigation: same rollback as `halted()`.
- **`user://` unreachable on Android (V3).** Mitigation: desktop MVP first; a share action later.
- **Enum renumbering by a later edit.** Mitigation: explicit values; baselines store ints, so a renumber fails the baseline compare at once.
- **`ChipState` kept past the frame by a view.** Mitigation: Implementation Guidelines; review; the instance holds values only, so a kept one is stale, never unsafe.
- **A lifecycle notification arrives inside `_process` (Decision 2 assumption).** Mitigation: ADR-0003 SP10, SP11 and ADR-0004 V7 record timing, the kit logs `between_ticks()` in the handler; if false, `pause()` defers to the next step 0 by amendment.
- **Policy bots drift from the Python table.** Mitigation: the Hero GDD names the script as the tie-breaker; bot stories cite it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| tower-system.md | TR-tower-001: TowerSim headless; TowerInput wrapper-only, changes state only through upgrade | Decisions 1, 8 |
| tower-system.md | TR-tower-002: build and upgrade are the only mutation API, between ticks, typed result in check order | Decisions 2, 3, 4 |
| tower-system.md | TR-tower-008: one non-negative int gold on TowerSim, three faucets, frozen once halted | Decision 6 |
| tower-system.md | TR-tower-009: bonus is to_ticks(seconds_left) div to_ticks(rate) | Decision 6 |
| tower-system.md | TR-tower-011 (ADR-0008's): TowerInput ignores taps while halted | Decision 8 (`halted` injected) |
| hero-system.md | TR-hero-001: HeroSim headless; HeroInput wrapper-only, changes state only through pin and burst | Decisions 1, 8 |
| hero-system.md | TR-hero-002: pin and burst between ticks, ordered codes, state before geometry, refusal mutates nothing | Decisions 2 to 5 |
| hero-system.md | TR-hero-009: read-only queries and per-run counters | Decision 7 |
| hero-system.md | TR-hero-012: resolver and direct scripts tick-identical; never-pinned equals absent | Decision 9 |
| hero-system.md | TR-hero-015: burst_button_centre() HUD-owned, read once, injectable | Decision 8 |
| battle-hud.md | TR-hud-012: screen and log read one snapshot taken the frame after the outcome | Decisions 10, 11 |
| battle-hud.md | TR-hud-013: debug-only JSONL run log through an injectable sink, failure non-fatal | Decision 10 |
| battle-hud.md | Foundational, no TR: B10's HUD-requested reads and the cooldown total | Decision 7 |
| input-gesture-resolver.md | TR-input-015: debug-only gesture log through an injectable sink | Decisions 8 (`chip_open`), 10 (sink, file) |
| input-gesture-resolver.md | Rule 11: bots call the commands; one equivalence test | Decision 9 |
| game-state-stage-flow.md | QQ-18: Start/Call method names and results (Rules 6, 9) | Decision 3 |

## Performance Implications
- **CPU**: Commands run a few times per frame at most, each with one to three accessor reads; `best_victims` is at most 2,304 squared-distance tests per burst release (about every 10 s). Negligible.
- **Memory**: A few hundred bytes per battle; two arrays grow by one `int` per burst.
- **Load Time**: None (debug builds open two files at boot).
- **Network**: None.

## Migration Plan

No code exists. On acceptance, apply the cascade edits in one change, then write Tower, Hero and HUD stories against Key Interfaces. The Pillar 4 harness story switches its interim sink to `JsonlFileSink`.

**Rollback plan**: Enum values only grow. If the between-ticks fatal proves too blunt, it becomes `dev_error` plus `HALTED` with no interface change. If chip timing must become sim state, a superseding ADR moves it into TowerSim on tick time; commands and enums stay.

## Validation Criteria

After acceptance, in the Tower, Hero and HUD stories:

1. Each refusal code in check order: empty recording log, `state_fields()` unchanged, spy read log exactly the reads before it.
2. A spy latching `fatal` on the cost read: `HALTED`, gold and slots unchanged.
3. A command from a test listener during `battle.tick`: `fatal` names it, `HALTED`, nothing mutated.
4. Gold: a 0 bounty or bonus emits nothing; halted pays nothing; 900, 863, 107 ticks pay 8, 7, 0.
5. Equivalence (Hero 27) and never-pinned (Hero 28) pass on the minimal and starter fixtures.
6. Two `ScriptBot` runs on one input give equal digests and result arrays.
7. RunLog with a recording sink: one line per WON/LOST attempt and per `CallResult.OK`, none for FATAL; a `false` write gives one `dev_error`; a release export writes no file (V2).
8. TowerInput with a `FakeResolver`: tap to `slot_tapped`; commit window 200 to 1500 ms; taps ignored while halted.
9. The ADR-0001 weakref test passes with all input and log classes attached and detached.

## Related

- Depends on ADR-0004, ADR-0007, ADR-0008, ADR-0009; binding ADR-0001, 0002, 0005, 0006. Enables ADR-0011.
- Amends (exact edits in the cascade notes): ADR-0006 Decision 5 (P1, P4, P6, P7 consumers; P4 required after attach), ADR-0001 (`attach` gains `dev_logs`), ADR-0004 Decision 5 (between-ticks check in every build), ADR-0008 Decision 8 (`chip_open` and sink slots), `architecture.md` B9 (`between_ticks` row).
- Settles: ADR-0004 item 15, ADR-0006 Decision 6 (snapshot class), ADR-0008 Decision 9 items 1 to 3 and choice 7, ADR-0009's float-position constraint, `architecture.md` QQ-18 and B10.
- GDDs: tower-system.md, hero-system.md, battle-hud.md, input-gesture-resolver.md, game-state-stage-flow.md (rules as cited above).
