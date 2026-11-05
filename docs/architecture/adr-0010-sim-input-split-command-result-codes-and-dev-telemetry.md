# ADR-0010: Sim/Input Split, Command Result Codes and Dev Telemetry

## Status
Proposed

## Date
2026-11-05

## Last Verified
2026-11-05

## Decision Makers
Najeeb Jarrar (owner). Drafted 2026-11-05 by lead-programmer in an autonomous run (the owner instructed it to decide, record the rationale and list open points as Verification rows). Reviews held 2026-11-05: technical-director (TD-ADR: CONCERNS, 5 concerns) and godot-specialist (APPROVE WITH FIXES, 1 blocking, 9 minor). Every finding was applied in the same day's fix round, with two rulings where they differed (command argument types stay `Vector2`; `seed` and `launch` are written as strings). Fix round 2026-11-05 after architecture-review-2026-11-05 (items applied: C2, C3, C4, Flow enums (QQ-18, V8), D2, D10, BUTTON_RADIUS, Depends On ADR-0003). Fix round 2 2026-11-05 after architecture-review-2026-11-05b (items applied: E4 Flow's caller treats its refusals as ordinary).

## Summary
Tower and Hero each split into a headless `RefCounted` sim (`TowerSim`, `HeroSim`: state, the guarded commands, the tick body) and a presentation-side input object (`TowerInput`, `HeroInput`: resolver signals to commands, hit radii, chip window, cancel hysteresis). This ADR fixes the command result enums (`OK = 0`, `HALTED`, `REENTERED`), the `_in_command` flag and read-before-mutate discipline, gold ownership, the `Tower` and `Hero` live-entity objects, the authoritative registrations table, the bot roster and command-script format, and the dev-only `RunLog` with its sink, schema and flush rule.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (pinned; 4.7.2 installed at pin time) |
| **Domain** | Core (sims, bots) with Input and Presentation (input objects, telemetry) |
| **Layer** | Core |
| **Knowledge Risk** | MEDIUM (GDScript classes, signals and `FileAccess` only; no scene, physics or rendering API) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `breaking-changes.md` (`FileAccess.store_*` return `bool` since 4.4, line 91); ADR-0001 (method-Callable injection, no back-references, `halted()`, `dev_error`); ADR-0004 (tick slots, `in_tick`, seed source, float policy); ADR-0005 (`ReadContext`, command context); ADR-0006 (`in_dispatch`, observers); ADR-0008 (resolver API, informative registrations); ADR-0009 (`live_entity` pattern, `Combat` API); the probe table below (4.7.2 probe, 2026-11-05, `prototypes/adr-0010-probe/`) |
| **Post-Cutoff APIs Used** | `FileAccess.store_line` returning `bool` (4.4; observed `true`, probe P3; also in `breaking-changes.md`). Nothing from 4.5 to 4.7 |
| **Verification Required** | See Verification table at the end of Decision: release-export value of `OS.is_debug_build()`, `user://` writes on a phone, and four design-reading gaps |

### Probe results (4.7.2.stable.official.ed1daf0bf, macOS, `--headless -s`; 4.7.2 probe, 2026-11-05, `prototypes/adr-0010-probe/`; caveat: desktop debug editor binary only)

| # | Claim | Result |
|---|---|---|
| P1 | `OS.is_debug_build()` headless | `true` |
| P2, P3 | `FileAccess.open(p, WRITE_READ)` on a new path, `seek_end`, `store_line("..")`, `get_error()` | Not null; `store_line` returns `true` (a `bool`); `get_error()` is 0 (OK) |
| P4 | `WRITE_READ` on an **existing** file | **Truncates**: `get_length()` is 0. An append sink must not use it |
| P5, P6 | `READ_WRITE` on an existing file, `seek_end`, `store_line` | Opens, keeps content (length 2 before append); appended text `x\ny\n`; returns `true` |
| P7 | `WRITE_READ` into a missing directory | Returns `null`; `FileAccess.get_open_error()` is 7 (file not found) |
| P8 | `READ_WRITE` on a missing file | Returns `null`; open error 7. So the sink creates the file first with `WRITE`, then reopens `READ_WRITE` |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted: builder, method-Callable injection, `halted()`, `dev_error`, roots); ADR-0003 (the adapter's lifecycle and field units); ADR-0004 (Proposed: slots, `in_tick`, `to_ticks`, `SeedSource`, snapshot); ADR-0005 (Proposed: `ReadContext`, command context); ADR-0006 (Proposed: `in_dispatch`, observer rules, commit-then-emit); ADR-0008 (Proposed: resolver); ADR-0009 (Proposed: `Combat`, `targets()`). The Proposed ones must be Accepted before any story that implements this ADR |
| **Delegates To** | ADR-0007: the lint rows named in Decision 12 and the baseline runner using `bot_id`; ADR-0011: rendering of arc, chip, ring, field tint and the view clock; nothing for Flow's command result codes: they are decided here (Decision 2, `Flow.StartResult`, `Flow.CallResult`) |
| **Enables** | ADR-0007 lint L16 (named files), baseline file names, ADR-0011 views reading `chip_state()`, `aim_state()`, `tower_at()` |
| **Blocks** | Every TowerSim, HeroSim, TowerInput, HeroInput and RunLog story; the bot baselines |
| **Ordering Note** | `architecture.md` B8, B10, Data Flow 9 and the TR-hud-018 row change at `/architecture-review` (see Sync section). TR-hud-018 was registered at that review (2026-11-05) |

## Context

### Problem Statement
Tower and Hero both say "two pieces" and defer to an ADR for: the command result codes and the re-entrancy refusal ADR-0006 left open, the read-before-mutate rule, whether towers and the hero are objects a `ReadContext` can reference, the hit radii and the registrations they feed, the cost-chip window owner, the bot roster and how a bot is proved equivalent to a human, and the dev run log (TR-hud-013, TR-hud-018). Nothing in `src/` exists yet, so every one of these is a clean-sheet choice.

### Constraints
- The battle is a pure function of (catalogue, stage_id, seed, command script) (ADR-0004). `src/battle/` holds `RefCounted` only; method-Callable injection; no lambda, `bind()`, `static var`, `assert` or `CONNECT_DEFERRED` (ADR-0001).
- Commands run only between ticks, synchronously from the input call stack (ADR-0004 Decision 7). Observers never call a command (ADR-0006).
- Stats are read through the accessor at use time; the cost of a not-yet-built level is read through ADR-0005's command context, never by writing the built tower's `level`.
- Telemetry listens only and cannot change a result; release builds never write it.

### Requirements
- TR-tower-001, 002, 006, 008, 009; TR-hero-001, 002, 009, 010, 012, 015; TR-hud-013 and TR-hud-018; TR-input-012 (radii), TR-input-015 (gesture log).
- A fake sink, fake sims and fake resolver must be enough to test every class here without an engine scene.

## Decision

**1. The split and where the files live.** All under ADR-0001's roots.

| Class | File | Role |
|---|---|---|
| `TowerSim` | `src/battle/tower_sim.gd` | Gold, slots, `build`, `upgrade`, tick body, gold reactors |
| `Tower` | `src/battle/tower.gd` | One built tower: `slot_index`, `def_id`, `level`, `cooldown_left`, its `context` |
| `HeroSim` | `src/battle/hero_sim.gd` | Pin, walk, auto-attack, burst, counters, tick body |
| `Hero` | `src/battle/hero.gd` | The hero's state as float scalars, its `context` |
| `PinGeometry` | `src/battle/hero/pin_geometry.gd` | `is_valid`, `clamp`, reach check; scalars only (ADR-0004 Decision 12) |
| `ScriptedCommand`, `CommandScript`, `CommandPlayer` | `src/battle/command_script.gd`, `command_player.gd` | The command-script format and its replay |
| `Bot`, `BotProfile`, `ProfileBot`, `BotRoster`, `BotRunner` | `src/battle/bots/*.gd` | Reactive bots, roster, recorder |
| `TowerInput`, `ChipWindow` | `src/presentation/input/tower_input.gd`, `chip_window.gd` | Registrations, slot/tower taps, chip window |
| `HeroInput` | `src/presentation/input/hero_input.gd` | Registrations, pin clamp, aim, hysteresis |
| `RunLog`, `FileRunLogSink`, `GestureLog` | `src/presentation/telemetry/*.gd` | Dev telemetry |
| `FakeRunLogSink` | `tests/support/fake_run_log_sink.gd` | Recording sink for tests |

`HudLogic` keeps the path ADR-0011 gives it. The sims never name an input object, a view or `RunLog`; input objects hold the sims (call-down) and the resolver. Bots live in `src/battle/bots/` because ADR-0004 baselines run them headless and they read only `Battle`'s public surface.

**2. Result codes (confirms B8 with two amendments).** Every command returns an enum whose first member is `OK = 0`; `HALTED` and `REENTERED` follow, so the order is stable and `result != BuildResult.OK` (the member of the command's own enum) is the refusal test. A bare `OK` is `@GlobalScope.OK` and compares equal only because both are 0, so code and lints write the qualified name.

```
TowerSim.BuildResult   { OK = 0, HALTED, REENTERED, BAD_SLOT, BAD_TOWER, SLOT_OCCUPIED, NO_GOLD }
TowerSim.UpgradeResult { OK = 0, HALTED, REENTERED, BAD_SLOT, NO_TOWER, MAX_LEVEL, NO_GOLD }
HeroSim.PinResult      { OK = 0, HALTED, REENTERED, BAD_POSITION, OUT_OF_BOUNDS, BUTTON_ZONE }
HeroSim.BurstResult    { OK = 0, HALTED, REENTERED, BUILD_PHASE, NOT_PINNED, NOT_READY, BAD_POSITION, OFF_FIELD, OUT_OF_REACH }
```
- **Amendment 1:** `REENTERED` is new. It is returned when `in_dispatch()` is true (the command was called from a tick or from another command's emit). It also calls `dev_error` once. It is checked second, right after `HALTED`. **Only `REENTERED` is a dev error raised by the sim**; `HALTED`, `NO_GOLD` and the pure refusals are ordinary results and report nothing (this narrows ADR-0006 Decision 3's wording, see Sync; ADR-0001 Decision 8 was amended to match on 2026-11-05).
- **Amendment 2:** none of the GDD orders change; `MAX_LEVEL` stays before `NO_GOLD` (Tower edge case: a second `upgrade` is `MAX_LEVEL`). `HALTED` is also re-checked after the cost read (Tower Rule 5).
- **State before geometry, refusal is inert.** A refusal returns before any mutation and emits nothing; no counter moves (`repins`, `slows_applied`). The enum lists the checks in order: `HALTED`, `REENTERED`, index and ID checks (non-fatal `is_tower`, `level_count`, Data Rule 10), occupancy, level, then the cost read, `HALTED` again, `NO_GOLD`, commit. Hero: `HALTED`, `REENTERED`, `BAD_POSITION`, `OUT_OF_BOUNDS`, `BUTTON_ZONE`; burst: `HALTED`, `REENTERED`, `BUILD_PHASE`, `NOT_PINNED`, `NOT_READY`, `BAD_POSITION`, `OFF_FIELD`, `OUT_OF_REACH`.
- **Callers.** `HeroInput` and `TowerInput` treat any result other than `OK`, `HALTED` and (for the chip) `NO_GOLD` as a development error via `dev_error`; `REENTERED` is already reported by the sim, so the caller does not report it twice. Bots log every non-`OK` code into the recorded script. Flow's caller (the HUD, through HudLogic) treats `OK`, `HALTED`, `WRONG_PHASE` and `NOT_CALLABLE` as ordinary: a Start or Call tap can race the countdown's expiry or a second tap (Flow GDD edge cases), so those refusals are expected and report nothing.
- **Flow's result enums (closes QQ-18 and V8).** Same rules as the sims (`OK = 0` first, qualified names, state before geometry, a refusal mutates and emits nothing, `_in_command` set only after the refusal checks and cleared at the single return):
```
Flow.StartResult { OK = 0, HALTED, REENTERED, WRONG_PHASE }
Flow.CallResult  { OK = 0, HALTED, REENTERED, WRONG_PHASE, NOT_CALLABLE }
```
`start_wave()` refuses `WRONG_PHASE` outside Build (including Paused: Flow's commands do nothing there, Flow GDD Rule 10). The early call refuses `WRONG_PHASE` outside Intermission (no call while a wave runs at MVP) and `NOT_CALLABLE` when the countdown is already at 0 (the GDD ignores a call at 0 with no signal). `HALTED` is ordinary and silent, `REENTERED` calls `dev_error` once. `pause()` and `resume()` return nothing and are inert in a wrong state; under `in_dispatch()` they refuse and call `dev_error` once.

**3. `in_command()` and the flag discipline (ADR-0006 Decision 3).** Each sim holds `_in_command: bool` and exposes `in_command() -> bool`. A public command is a thin wrapper around a private commit:

```
func build(slot_index: int, tower_id: StringName) -> BuildResult:
    if _halted.call(): return BuildResult.HALTED
    if _in_dispatch.call(): _dev_error.call("build while in_dispatch"); return BuildResult.REENTERED
    var pre: BuildResult = _check_build(slot_index, tower_id)   # pure: BAD_SLOT, BAD_TOWER, SLOT_OCCUPIED
    if pre != BuildResult.OK: return pre
    _in_command = true
    var r: BuildResult = _commit_build(slot_index, tower_id)    # reads, then mutate, then emit
    _in_command = false
    return r
```
The flag is set only after every refusal check and cleared at the single return of the wrapper, so a private commit that returns early (`HALTED`, `NO_GOLD`) cannot leak it. `_commit_*` must never be called except from the wrapper (review item; the single-writer lint L22 covers `_in_command`). The flag is true while the command's own signals emit, so an observer that calls a command gets `REENTERED`. The gold reactors (`on_enemy_killed`, `on_wave_called_early`) are not commands and set no flag: they run inside a tick or inside Flow's `call_early`, whose own flag or `in_tick()` already covers them.

**4. Read-before-mutate.** A commit reads every accessor value it needs, checks `halted()` after the last read, and only then mutates. `build`: read `cost` (command context, level 1), check halted, compare gold, then debit, create the `Tower`, emit `gold_changed`, emit `tower_built`. `upgrade`: read `cost` (command context, level + 1), then debit, write `level`, emit `gold_changed`, emit `tower_upgraded`. `pin`: read `walk_speed` before setting the target; `walk_ticks = max(1, ceil(distance / (walk_speed * dt) - 0.0001))` for distance above 0 (Hero GDD Formulas: movement, so it rounds up and does not use `to_ticks`), a pin at the hero's own position is Pinned at once; the position is `from + (pin - from) * (1 - float(walk_left) / float(walk_ticks))` and is assigned the pin exactly at `walk_left` 0. **Precision rule:** `pin(pos: Vector2)` and `burst(pos: Vector2)` keep B8's argument type (Hero GDD: points arrive and leave as `Vector2`). At command entry the sim unpacks `.x` and `.y` into 64-bit `float` locals and uses scalars only inside (ADR-0004 Decisions at lines 77 and 124); `Vector2` appears only at the edges (commands, `position()`, signals). `ScriptedCommand.x` and `.y` store the 32-bit-rounded components of the `Vector2` the command received, so a replayed script matches the resolver path (TR-hero-012). `burst`: read `reach` and `telegraph_duration` before starting the telegraph. A bad read latches the fatal and the command returns `HALTED` with state untouched. After each emit the commit checks `halted()` and, if set, stops emitting but still returns `OK` (the state change did commit).

**5. Gold.** `TowerSim` owns one non-negative `int` and emits `gold_changed(current: int)` only when it changes (ADR-0006). Faucets: `starting_gold` read once at build from the Stage record; `on_enemy_killed(bounty: int)` connected to Enemy & Wave's signal; `on_wave_called_early(seconds_left: float)` connected to Flow's. Both reactors return at once if `halted()` (gold freezes, TR-tower-008). The bonus: `early_call_bonus(seconds_left) -> int` is pure and returns integer `to_ticks(seconds_left) / to_ticks(early_call_seconds_per_gold)`; the payout reactor and HudLogic's "Call +N" both call it (TR-tower-009). A zero bonus emits nothing. TR-tower-009's clause that `seconds_left` includes the tick the next wave starts on is Flow's to compute when it emits `wave_called_early`; `TowerSim` adds and subtracts nothing, and a test feeds N ticks of seconds and expects `N / to_ticks(rate)`. `early_call_seconds_per_gold` is a Stage field injected at build, not an accessor stat. Cost reads for `NO_GOLD` go through the command context (Decision 6), never the built tower's context.

**6. `live_entity` objects and `ReadContext` construction.** Following ADR-0009's pattern (entity owns its context; the context holds a `WeakRef`):
- `Tower` (RefCounted) holds `slot_index`, `def_id`, `level`, `cooldown_left` and `context: ReadContext`, created in `Tower._init` as `ReadContext.new(def_id, level, self)`. `TowerSim` alone writes `level` and `cooldown_left`, and writes `level` only inside the commit of an upgrade after the debit and before the emits (ADR-0005).
- `TowerSim` also owns one **command context** built in `_init` (`live_entity` wraps `null`): `def_id` and `level` are assigned before each cost read (level 1 for `build`, tower level + 1 for `upgrade`) and by `TowerSim` only.
- `Hero` (RefCounted) holds float scalars `x`, `y`, `from_x`, `from_y`, `pin_x`, `pin_y` and ints `walk_left`, `walk_ticks` and its `context` (`ReadContext.new(hero_def_id, 0, self)`). The **Burst context** is `ReadContext.new(burst_id, 0, null)`: the burst has no object at MVP (recorded Vertical Slice touch-point, ADR-0005 line 132).
- Contexts are built once, when the owner or entity comes to exist (tower build, `HeroSim._init`). **None is constructed per tick or per command**: the tick and command paths only assign `def_id` and `level` on an existing context. `HudLogic` keeps its two preview contexts (ADR-0005).
- `tower_at(slot_index) -> Tower` returns the live object or `null` (empty or out of range); views and the HUD read `Tower` fields but never write them (lint L22 extends to `Tower` and `Hero` fields).

**7. Tick bodies.** The GDD step lists are normative and are not restated: Tower Rule 9 (cooldown, `first_in` or slow-first targeting, read the rest before changing anything, set `cooldown_left`, `report_attack`, `deliver`, `apply_slow`) and Hero tick steps 1 to 7. Both run `tick() -> void` with no arguments, check `halted()` after every read and signal, and receive `Combat`, a `targets` method Callable (ADR-0009: never stored result), the accessor, `to_ticks`, `halted`, `in_dispatch`, `dev_error`, and the catalogue's non-fatal `is_tower` and `level_count`. `TowerSim` counts `apply_slow` calls in `slows_applied()`.

**8. The registrations table (authoritative; supersedes ADR-0008 Decision 11's informative table).** Radii are the art bible §3 values via Input GDD line 37 and Battle HUD Rule 9; each is a `const` on the owning input object, never in the resolver.

| Owner | Target | Kind | Priority | Radius | Centre / lifetime |
|---|---|---|---|---|---|
| TowerInput | Empty slot | TAP | 200 | 36 (`SLOT_RADIUS`) | Slot point; disabled once built |
| TowerInput | Built tower | TAP | 200 | 36 | Same point; enabled once built |
| TowerInput | Chip disc | TAP | 300 | 40 (`CHIP_RADIUS`) | Tower (x, y - 76) while the window is open |
| HeroInput | Hero | DRAG | 200 | 56 (`HERO_RADIUS`) | `set_centre` every frame the hero walks |
| HeroInput | Burst button | DRAG | 100 | 48 (`BUTTON_RADIUS`) | Read once from `burst_button_centre()` |
| HeroInput | Button sink | SINK | 400 | 48 (`SINK_RADIUS`, equal to the button) | Same as button |
| HudLogic | Arc backdrop | SINK | 250 | 600 (`ARC_BACKDROP_RADIUS`) | Field centre (270, 480); covers every field point |
| HudLogic | Arc discs (3) | TAP | 300 | 36 (`ARC_DISC_RADIUS`) | Opens on `slot_tapped`, unregisters on close |
| HudLogic | Start/Call | TAP | 350 | 48 (`START_CALL_RADIUS`, the burst button's size; decided here, phone test P1 may change it) | Registered by HudLogic; disabled while the arc is open |

`BUTTON_RADIUS = 48` on HeroInput is the burst-line constant that ADR-0002's HUD content row reads.

**Arc and halted behaviour (TR-hud-008, TR-tower-011, TR-hero-010).** `HudLogic` registers the arc backdrop and discs on `slot_tapped`, calls `set_enabled(start_call_id, false)` while the arc is open, and on `phase_changed` to WON, LOST, PAUSED or FATAL closes the arc (unregisters, re-enables Start/Call). `TowerInput` sets its slot, tower and chip targets disabled while `halted()` and closes the chip on the same `phase_changed`. `HeroInput` calls `set_centre` for the hero target every frame the hero walks and evaluates the hysteresis itself. Priorities and kinds agree with ADR-0008 Decision 11; the two amendments are the second per-slot registration (slot and tower are separate targets so TR-tower-011's "disable a built slot" is a `set_enabled` flip) and the explicit radii. Also on the input objects: `AIM_OFFSET_Y = -100.0`, `CANCEL_OUT = 64.0`, `CANCEL_IN = 48.0` (Hero GDD Rules 12 and 13: presentation constants, bots skip them), `CHIP_WINDOW_MS = 1500.0`, `BOUNCE_GUARD_MS = 200.0` (passed as constructor defaults so tests inject 3000). These are presentation tuning values the GDDs fix; they are the one place a literal is allowed, and the content tests (ADR-0002 Decision 12) read them by name.

**9. TowerInput.** Built per battle by the wrapper after the sims; holds the resolver, `TowerSim` and a `ChipWindow`. Listeners: `tapped(best_tap, p)` and `pressed`, plus Flow's `phase_changed`. It ignores every tap while `halted()` (TR-tower-011). On a tap naming an empty slot it emits `slot_tapped(slot_index: int)`. On a built tower below its last level it opens the chip (or, inside `200 <= elapsed < 1500` ms with the same tower, calls `upgrade`; `NO_GOLD` keeps it open and dimmed, any other result closes it). At the last level it emits `tower_inspected(slot_index: int)` and opens no chip. The window runs on the **frame clock**: the wrapper calls `TowerInput.advance(view_dt_ms: float)` once per frame with ADR-0004's `view_dt` (0 under Pause), so there is no `_process` in the class and the order is fixed: resolver emissions at frame start, then `advance`. `chip_state()` returns slot, elapsed, window and level for HudField. Closing on Paused, Won, Lost and Fatal comes from `phase_changed`. `slot_tapped` and `tower_inspected` are presentation signals (ADR-0006 observers may emit them); the HUD, not the sim, is the listener.

**10. HeroInput.** Registers per Decision 8. Pin: the finger point (plus `pin_offset`, 0 at MVP) goes through `PinGeometry.clamp`, then `HeroSim.pin`. Aim: Hero Rules 11 to 13 verbatim; cancel hysteresis is evaluated by HeroInput on `drag_started`, each `drag_moved` and `drag_ended`, with `CANCEL_OUT` and `CANCEL_IN`; `burst(aim_point)` is called on `drag_ended` unless cancelling; `drag_cancelled` and `became_idle` clear the aim. The pin trigger is `drag_ended` on the hero target (Hero GDD Overview: a drag from the hero sets its pin); `ground_tapped` does nothing for the hero. It reads `aim_state()`, `button_press()`, `cooldown_digit()` for HudField (B10).

**11. Bot equivalence.** Bots are reactive (the Hero GDD bots fire when 5 enemies fit in the radius), so a bot cannot pre-emit a script. Instead:
- Bots connect no signal handler that issues commands, use no RNG and no `Time`, and only read `Battle`'s public surface. `Bot.act(battle: Battle, tick: int) -> Array[ScriptedCommand]` is called between ticks by `BotRunner`, which applies each command through `CommandPlayer.apply` and **records** it. A `ScriptedCommand` is `tick: int`, `op` (`BUILD`, `UPGRADE`, `PIN`, `BURST`, `START_WAVE`, `CALL_EARLY`), `slot: int`, `tower_id: StringName`, `x: float`, `y: float` (the 32-bit-rounded components, see Decision 4). The recorded `CommandScript` is an ordered `Array[ScriptedCommand]`.
- **Roster** (`BotRoster.IDS`, hyphenated so ADR-0007's `<stage_id>_<bot_id>_<os>_...` file name splits unambiguously on `_`): `towers-only`, `pinned-once`, `mid-skill`, `ceiling`, `mid-skill-calling`, from the Hero GDD simulated-results table; the table's "best single pin" bot (a grid search) is deliberately left out. Each has a `BotProfile` (re-pin interval, burst wait seconds, aim exact or offset, calls early, pins once) and the default build mix of 3 single, 1 splash, 1 slow, upgraded in pairs. Other mixes later add ids with a `-<mix>` suffix.
- **Test** (`tests/integration/battle/bot_replay_test.gd`): for every roster id run the bot to the outcome recording a script and the per-checked-tick snapshots; build a second `Battle` with the same inputs and replay the script through `CommandPlayer` alone; the snapshot arrays and result codes must be equal. Comparison with the stored baseline file is ADR-0007's `BaselineRunner`, not this test. A second test (TR-hero-012) feeds one scripted pointer sequence through resolver, `HeroInput` and `HeroSim` and the equivalent direct commands and compares `HeroSim` state tick by tick; a third compares a never-pinned run with a run whose builder omitted `HeroSim`.
- `CommandPlayer` ignores nothing: a non-`OK` code is stored on the script entry; replay must reproduce the same codes.

**12. Lint and test hand-offs to ADR-0007.** (a) L16's file list: `src/battle/hero/pin_geometry.gd` and `src/battle/hero_sim.gd` (the reach check) replace `owed: ADR-0010`. (b) Single-writer rows: `Tower` fields written only by `tower_sim.gd`, `Hero` fields only by `hero_sim.gd`, `_in_command` only by its own sim. (c) `src/battle/` never names `TowerInput`, `HeroInput`, `RunLog`. (d) `run_log.gd` and `gesture_log.gd` never reference `OS`, `Time`, `FileAccess` or a command method (`build`, `upgrade`, `pin`, `burst`, `start_wave`, `call_early`). (e) The `FakeRunLogSink` lives in `tests/support/`.

**13. Dev telemetry.**
- **Build gate.** The wrapper builds `RunLog` and `GestureLog` only when its `dev_telemetry` argument is true (`setup(battle, dev_telemetry)`, ADR-0001 Key Interfaces). `AppRoot` is the only reader of `OS.is_debug_build()` and passes it in (probe P1: `true` on the dev binary; the release-export value is V1). Tests pass both values in one process (ADR-0007 Decision 5). The wrapper holds `RunLog` as a nullable field and connects its listeners only when it exists. `RunLog` itself never reads `OS`.
- **Sink.** `RunLog` receives a method Callable `write_lines: Callable` of signature `(PackedStringArray) -> bool`. `FileRunLogSink.write_lines(lines: PackedStringArray) -> bool` appends to `user://run_log.jsonl` with one open per flush: if the file does not exist, open `WRITE` and close; then `READ_WRITE`, `seek_end`, `store_line` per line, close, and return false at the first failed `store_line`. A `null` from either `open` returns false (probe P7, P8) (probe P4: `WRITE_READ` would truncate; P8: `READ_WRITE` needs an existing file). `FakeRunLogSink` records lines and has `fail_next`.
- **Flush.** Events append a finished JSON line to a `PackedStringArray` buffer. The wrapper calls `run_log.advance(view_dt)` (seconds, the same `view_dt` it gives `TowerInput.advance` in ms) and `run_log.flush()` once per frame, next to `TowerInput.advance(view_dt_ms)` and `HeroInput.update()` (TR-hero-011), which the wrapper also calls every frame; `HudLogic` is unaware of `RunLog`; `flush()` does nothing if the buffer is empty, drops the whole buffer if the injected `is_fatal()` is true, else passes the buffer to the sink in one call. Fatal drops everything buffered in the current frame: the fatal frame's call record and GestureLog lines are lost too, which matches TR-hud-018's "Fatal drops it"; earlier frames were already written. A write returning `false` drops that frame's remaining lines, increments `write_failures` and issues one `push_warning` (injected `warn` Callable); it never fatals, never retries and never grows the buffer. Release builds hold no `RunLog` at all, so they are silent.
- **Order.** A pending call record is appended before the attempt record on the same flush; both come from `phase_changed(WON|LOST)`. A call record is written when `RunLog` sees `phase_changed(INTERMISSION)` (already allowlisted in ADR-0006) or the outcome phase; RunLog connects no `wave_cleared` handler.
- **Fatal overrides Won.** If the latch sets in the same tick after `phase_changed(WON)` has buffered the attempt record, `flush()` sees `is_fatal()` and drops both. Test: fake Flow emits WON, fake `is_fatal` flips, `advance` runs, sink received 0 lines; control: not fatal, sink received call then attempt.
- **Attempt record (TR-hud-018).** One JSON object per line, `"k":"attempt"`: `launch` (the `SeedSource` base) and `seed` are written as decimal `String`s, because JSON turns 64-bit ints into floats and loses low digits (ADR-0004 line 124 probe), which would defeat reproducing the run; `launch`, `build_id` (string, injected, V4), `stage`, `attempt` (AppRoot's counter n), `outcome`, `towers` (IDs in build order), `lives`, `last_wave`, `dmg_by_id`, `dmg_by_kind` (`tower`, `hero`, `burst`), `hero_share`, `slows`, `repins`, `repins_w1` (captured at the first WAVE phase), `bursts`, `bursts_hit_0`, `kills_per_burst` (array), `best_victims`, `through` (by enemy type), `t_first_pin`, `t_first_build`, `t_first_burst` (frame-clock seconds from the first frame, -1.0 if never; the frame clock freezes under Pause, so these exclude paused time, unlike the GDD's "real seconds"). Events are stamped with the battle's tick counter (ADR-0004's `tick` member on `Battle`, read at record time; ADR-0009 line 120). Call record, `"k":"call"`: `attempt`, `seconds_left`, `burst_state`, `pin_state` (both sampled from `HeroSim` at `wave_called_early`, never through Tower), `lives_lost` (lives at the call minus lives at the next `wave_cleared` or outcome). A quit leaves no record.
- **GestureLog** (ADR-0008 delegation, TR-input-015) is a second dev-only observer that appends `"k":"gesture"` lines through the same buffer: resolver transitions (`recent_transitions()`), `tower_upgraded`, `chip_state()` at prompts and `burst_started`. Its field list is fixed by the Pillar 4 phone-test story (V7).

### Architecture Diagram
```
Resolver signals ──► TowerInput ──► TowerSim.build/upgrade ─┐       Bot.act ──► CommandPlayer ──┐
                 ├─► HeroInput  ──► HeroSim.pin/burst      ─┼──► (guard: halted, in_dispatch)   │
                 └─► HudLogic   ──► TowerSim.build         ─┘                                  ▼
Battle.tick: Flow, Wave.advance, tick_status, TowerSim.tick, HeroSim.tick, reap  ◄── same commands
Sim signals ──► observers: HudLogic, views, RunLog (buffer) ──► wrapper: advance, flush ──► sink
```

### Key Interfaces
```gdscript
class_name TowerSim extends RefCounted
static func create(catalogue: Catalogue, stage: StageRecord, accessor: StatAccessor, combat: Combat,
        targets: Callable, to_ticks: Callable, halted: Callable, in_dispatch: Callable,
        dev_error: Callable) -> TowerSim
func build(slot_index: int, tower_id: StringName) -> BuildResult
func upgrade(slot_index: int) -> UpgradeResult
func tick() -> void
func in_command() -> bool
func gold() -> int
func slot_count() -> int
func tower_at(slot_index: int) -> Tower          # null when empty or out of range
func early_call_bonus(seconds_left: float) -> int
func slows_applied() -> int
func on_enemy_killed(bounty: int) -> void
func on_wave_called_early(seconds_left: float) -> void
signal gold_changed(current: int)
signal tower_built(slot_index: int, tower_id: StringName)
signal tower_upgraded(slot_index: int, level: int)

class_name HeroSim extends RefCounted
func pin(pos: Vector2) -> PinResult
func burst(pos: Vector2) -> BurstResult
func tick() -> void
func in_command() -> bool
func position() -> Vector2
func pin_target() -> Vector2
func pin_state() -> int
func burst_state() -> int
func cooldown_left() -> int
func repins() -> int
func bursts() -> int
func bursts_hit_0() -> int
func kills_per_burst() -> PackedInt32Array
func best_victims() -> int
signal hero_pinned(position: Vector2)
signal burst_started(aim_point: Vector2, telegraph_ticks: int)

class_name TowerInput extends RefCounted
signal slot_tapped(slot_index: int)
signal tower_inspected(slot_index: int)
func advance(view_dt_ms: float) -> void
func chip_state() -> Dictionary                   # slot, elapsed_ms, window_ms, level (ADR-0011 reads)

class_name RunLog extends RefCounted
func begin(launch: int, build_id: String, stage: StringName, seed: int, attempt: int) -> void
func advance(view_dt: float) -> void              # frame-clock seconds, called by the wrapper
func flush() -> void
```
B8's `Vector2` argument types are kept; the precision rule is in Decision 4. The ID `tower_id` is `StringName` (closes QQ-04).

### Implementation Guidelines
- Commands must be the thin wrapper of Decision 3; a private commit must never be called from outside the wrapper; a command must never be called from a tick, from an observer or from another sim.
- A commit must read every accessor value before its first mutation and check `halted()` after the last read.
- Input objects must never write sim state except through the four guarded commands; observers must never call them.
- Hit radii, priorities, window and hysteresis must be `const` on the input objects and must never appear in the resolver or the sims.
- `RunLog` must only listen and read; must never call a command; must never reference `OS`, `Time` or `FileAccess`; must drop its buffer when `is_fatal()`.
- Contexts must be created once per owner or entity; the tick and command paths must never allocate a `ReadContext`.
- Bot, replay and baseline code must use `CommandPlayer` as the only command-issuing path.

## Alternatives Considered

### Alternative 1: Commands return `bool` plus a last-error field
- **Description**: `build()` returns success; the reason is read from `last_result()`.
- **Pros**: Smaller API; no enum per command.
- **Cons**: Two calls to read a refusal; a nested command overwrites the field; bots cannot log a code per entry; tests assert on mutable state.
- **Rejection Reason**: TR-tower-002 and TR-hero-002 require typed ordered result enums.

### Alternative 2: Bots as pre-computed command scripts
- **Description**: A bot emits a whole script from (catalogue, stage) before the battle runs.
- **Pros**: Replay is trivial; no recorder.
- **Cons**: The Hero GDD bots react to enemy positions, so the script cannot exist before the run.
- **Rejection Reason**: Reactive bots with a recorded script give the same replay property and keep the GDD bots.

### Alternative 3: `RunLog` always built, writes gated by a flag
- **Description**: Build it in release and let a bool suppress the sink.
- **Pros**: One code path; release tests the same classes.
- **Cons**: Release carries telemetry code and a buffer; a flag bug writes a file on a player's phone.
- **Rejection Reason**: TR-hud-013 says release builds never write; not building it makes that a structural fact.

### Alternative 4: Put bots in `tests/`
- **Description**: Bots are test support.
- **Pros**: Never shipped.
- **Cons**: Baselines are a CI artefact that must run the same code the sim sees; the Hero GDD has the Hero stories "build the real bots".
- **Rejection Reason**: `src/battle/bots/` is lint-covered like the sims; the exporter can exclude the folder (V10).

## Consequences

### Positive
- One result vocabulary for humans, bots and tests; a refusal is inert and provable.
- The flag cannot leak: one set, one clear.
- Telemetry cannot affect a result and cannot exist in release.
- Tower and Hero are objects, so the Vertical Slice modifier resolver needs no touch-point except the Burst.

### Negative
- Two registrations per slot and a reasoned constant table on four classes.
- The recorder adds a code path in `BotRunner`.

## Risks
- A command added later forgets the wrapper pattern: mitigated by the L22 single-writer row for `_in_command` (Decision 12 b) and review.
- `OS.is_debug_build()` (read in `AppRoot` only) true in a release export would write files: V1 with a CI check on the export.
- Chip `advance` frame clock lets one 0.1 s clamp stretch the window: accepted.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| tower-system.md | TR-tower-001 split | Decision 1 |
| tower-system.md | TR-tower-002 ordered result enums | Decisions 2 to 4 |
| tower-system.md | TR-tower-006 halted checked after every read and signal, reads before mutation | Decisions 3, 4 and 7 |
| tower-system.md | TR-tower-011 slots and chip registered, built slot disabled, chip closes on phase, taps ignored while halted | Decisions 8 and 9 |
| tower-system.md | TR-tower-008 gold ownership and freeze | Decision 5 |
| tower-system.md | TR-tower-009 early-call bonus shared | Decision 5 |
| hero-system.md | TR-hero-001 split | Decision 1 |
| hero-system.md | TR-hero-002 ordered result enums | Decisions 2 to 4 |
| hero-system.md | TR-hero-009 queries and counters | Key Interfaces |
| hero-system.md | TR-hero-010 hero DRAG, button DRAG and sink registered, `set_centre` per frame, hysteresis | Decisions 8 and 10 |
| hero-system.md | TR-hero-012 resolver-driven equals direct | Decision 11 tests |
| hero-system.md | TR-hero-015 `burst_button_centre()` read once | Decision 8 |
| battle-hud.md | TR-hud-008 arc registers and unregisters, disables Start/Call, closes on outcome, Paused or Fatal | Decision 8 (HudLogic reacts to `phase_changed`) |
| battle-hud.md | TR-hud-013 injectable sink, non-fatal, release never | Decision 13 |
| battle-hud.md | TR-hud-018 (registered 2026-11-05) run-log schema | Decision 13 |
| input-gesture-resolver.md | TR-input-012 radii on input objects; TR-input-015 gesture log | Decisions 8 and 13 |

## Performance Implications
- **CPU**: Commands are O(1) plus one accessor read; no allocation on the tick or command path. `RunLog` appends only on events and formats a line per record; one file open per frame at most.
- **Memory**: Five towers, one hero, one command context; a small string buffer in debug only.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
Greenfield (`src/` is empty). Create the files of Decision 1; the builder constructs `TowerSim` then `HeroSim` and injects `Battle.in_dispatch`; the wrapper builds `TowerInput`, `HeroInput`, then `RunLog` when its `dev_telemetry` argument is true (`AppRoot` passes `OS.is_debug_build()`). `/test-setup` scaffolds `tests/support/fake_run_log_sink.gd`.

## Validation Criteria
1. Each enum has `OK == 0`, and every refusal leaves `Battle.snapshot()` identical and emits nothing.
2. A command issued from a signal handler returns `REENTERED` for every sim.
3. A fatal accessor read inside `build` leaves gold and slots unchanged and returns `HALTED`.
4. Every roster bot replays to identical snapshots and the stored baseline.
5. Fatal-overrides-Won drops both records; a failing sink never fatals; a release build constructs no `RunLog`.
6. `grep` of `input_resolver.gd` and the sims finds no radius literal from Decision 8.

## Verification

| # | Claim | What to run / expected |
|---|---|---|
| V1 | NOT SOURCEABLE: `OS.is_debug_build()` (read only in `AppRoot` and passed to `setup`) is `false` in a release export template (probe P1 is the desktop editor binary, `true`) | Export a release APK, log the value at boot; expect `false` and no `run_log.jsonl`. An exported **debug** template is expected (unverified) to return `true` |
| V2 | NOT SOURCEABLE: `user://` writes and the `READ_WRITE` append sequence behave as on desktop on an Android debug export | Run the sink on a debug APK (expected to build `RunLog`, V1), pull the file; expect each line present, `write_lines` returns `true` |
| V3 | Sourced by ADR-0004's probe (line 124): `JSON` parses 64-bit ints as floats, so `seed` and `launch` are strings. Small ints (lives, counts) are assumed to print without a decimal point | `print(JSON.stringify({"a": 1}))`; expect `{"a":1}` |
| V4 | NOT SOURCEABLE: `build_id` source (a CI-written file) is not in the reference | Until CI writes it, `build_id` is `"dev"`; add a story |
| V5 | Closed by decision: `SINK_RADIUS` and `START_CALL_RADIUS` are 48 | Phone test P1 may change them; content tests read the constants by name |
| V6 | Closed: pin trigger is `drag_ended` on the hero target and the walk formula is cited in Decision 4 | None |
| V7 | Design gap: GestureLog field list | Fixed by the Pillar 4 phone-test story |
| V8 | Closed 2026-11-05: Flow's command result codes | Decided in Decision 2 (`Flow.StartResult`, `Flow.CallResult`); the guard test of ADR-0006 Decision 3 covers them |
| V9 | Closed: `Vector2` argument types kept, scalars inside (Decision 4) | None |
| V10 | `src/battle/bots/` excluded from the release export | Check export filter; expect no bot class in the APK |
| V12 | NOT SOURCEABLE: `user://` exists before the first `FileAccess.open` on a fresh install (desktop and Android); the reference does not cover its creation | Delete the app's user directory, launch, write one line; expect success, else create with `DirAccess` first |
| V11 | GDScript integer division warning (`to_ticks / to_ticks`) is not an error under the project warning settings | Run the parse check; expect pass, else use `@warning_ignore` |

## GDD and Registry Sync at Acceptance

Applied 2026-11-05 at acceptance; items not applied are listed below.

- Not applied: `design/gdd/tower-system.md`, `hero-system.md` and `battle-hud.md` items: held for the GDD pass (another owner).
- Not applied: architecture.md HeroInput row: `update()` kept, because Decision 11 (Flush) and ADR-0004 step 2b still call `HeroInput.update()` (TR-hero-011).

Applied at `/architecture-review`, not by this ADR. Format `file:line: old → new`.

- docs/architecture/architecture.md:529: `enum BuildResult { OK, HALTED, BAD_SLOT, ... }` → `{ OK = 0, HALTED, REENTERED, BAD_SLOT, BAD_TOWER, SLOT_OCCUPIED, NO_GOLD }`
- docs/architecture/architecture.md:530: `UpgradeResult { OK, HALTED, BAD_SLOT, ... }` → `{ OK = 0, HALTED, REENTERED, BAD_SLOT, NO_TOWER, MAX_LEVEL, NO_GOLD }`
- docs/architecture/architecture.md:534: `func slot_state() -> Array` → `func slot_count() -> int` and `func tower_at(slot_index: int) -> Tower`; add `func tick()`, `in_command()`, `on_enemy_killed(bounty)`, `on_wave_called_early(seconds_left)`
- docs/architecture/architecture.md:542-543: `PinResult { OK, HALTED, ...}`, `BurstResult { OK, HALTED, ...}` → `OK = 0` first, `REENTERED` after `HALTED`
- docs/architecture/architecture.md:549: Invariants line → add "`REENTERED` is checked second; `_in_command` is set after the refusal checks and cleared at the wrapper's single return; `HALTED` is also re-checked after the cost read"
- docs/architecture/architecture.md:573: B10 HUD read surface → add `HeroSim.repins()`, `bursts()`, `bursts_hit_0()`, `kills_per_burst()`, `best_victims()`, `burst_state()`, `pin_state()` and `TowerSim.tower_at()`
- docs/architecture/architecture.md:335: Data Flow 9 "Development builds only." → "RunLog and GestureLog are built by the wrapper only when its `dev_telemetry` argument is true (`AppRoot` passes `OS.is_debug_build()`); events buffer, the wrapper flushes once per frame through the sink; the buffer is dropped when the latch is set (ADR-0010 Decision 13)"
- docs/architecture/architecture.md:594 (applied 2026-11-05): TR-hud-018 (provisional) → registered; schema per ADR-0010 Decision 13; add "Fatal drops both records, including a Won record buffered in the same tick"
- docs/architecture/tr-registry.yaml:912 (applied 2026-11-05; append after TR-hud-017): add TR-hud-018 from architecture.md:594 text, `status: active`, created 2026-11-05
- design/gdd/tower-system.md:55: result table row `HALTED | halted() is true | 1st, and again after the cost read` → add a new row after it: `REENTERED | in_dispatch() is true; the command refuses and reports through dev_error | 2nd`
- design/gdd/tower-system.md (Rule 8, the chip window sentence, "fed by the wrapper to a pure ChipWindow with advance(ms)") → "fed each frame by the wrapper's view_dt in ms through TowerInput.advance"
- design/gdd/hero-system.md:36: pin returns `HALTED`, `BAD_POSITION`, ... → insert `REENTERED` after `HALTED`
- design/gdd/hero-system.md:43: burst returns `HALTED`, `BUILD_PHASE`, ... → insert `REENTERED` after `HALTED`
- design/gdd/battle-hud.md:116: Rule 19 "Each record holds a launch ID and the build hash" → "launch ID is the SeedSource base; build_id is injected (ADR-0010 V4)"; add "RunLog buffers events and the wrapper flushes once per frame; a write failure drops that frame's lines and warns once"
- docs/architecture/adr-0007-headless-test-harness-gdunit4-and-layer-lint.md:93: L16 row "the file(s) ADR-0010 names" / "SKIPPED under the owed: ADR-0010 allowlist entry" → `src/battle/hero/pin_geometry.gd`, `src/battle/hero_sim.gd`; remove the allowlist entry (line 249)
- docs/architecture/adr-0007-headless-test-harness-gdunit4-and-layer-lint.md:72: "`bot_id` comes from ADR-0010's bot roster" → ids `towers-only`, `pinned-once`, `mid-skill`, `ceiling`, `mid-skill-calling` (hyphenated)
- docs/architecture/adr-0008-input-resolver-core-and-signal-contract.md:134: informative registrations paragraph → point at ADR-0010 Decision 8 as authority; two registrations per slot (slot, tower); radii 36/40/56/48/48
- docs/architecture/architecture.md:544-545: `pin(pos: Vector2)`, `burst(pos: Vector2)` → unchanged; add the precision rule (unpack to 64-bit floats at entry, scalars inside, `Vector2` at the edges; `ScriptedCommand.x/y` store 32-bit-rounded components)
- docs/architecture/architecture.md (module table, TowerSim/field-view rows): `slot_state()` → `tower_at(slot_index)` and `slot_count()`
- docs/architecture/architecture.md:156 (HeroInput row): Exposes `update()`, `aim_state()`, `aim_point()` ... → `aim_state()`, `aim_point()`, `button_press()`, `cooldown_digit()`; pin on `drag_ended` of the hero target (ADR-0010 Decision 10)
- docs/architecture/architecture.md:158 (ChipWindow row) and the HudLogic row: `advance(ms)` → `TowerInput.advance(view_dt_ms: float)` (ms) and `RunLog.advance(view_dt: float)` (seconds, called by the wrapper, with `RunLog.flush()`); HudLogic has no RunLog duty
- docs/architecture/adr-0005-stat-accessor-and-read-context-contract.md:131-132: "if ADR-0010 gives towers one, otherwise null" / "unless ADR-0010 gives the Burst an object" → settled: Tower and Hero are objects, the Burst has none at MVP
- docs/architecture/adr-0009-enemy-entity-roster-and-combat-api.md:102: "if ADR-0010 gives towers one" → settled as above
- docs/architecture/adr-0006-battle-signal-contracts-and-view-allowlist.md:66: "cleared on every return path" → "set after the refusal checks, cleared at the wrapper's single return" (same effect); a refused command reports through `dev_error` only for `REENTERED`, not for `HALTED`, `NO_GOLD` or the pure refusals
- design/gdd/tower-system.md:163: the "Becomes an ADR" note → closed by ADR-0010 (TowerInput placement, chip window fed by `view_dt`, signal signatures, `tower_id` is `StringName`)
- design/gdd/battle-hud.md:116: "the real seconds to first pin, build and burst" → "frame-clock seconds (paused time excluded)"; `seed` and `launch` are written as strings
- docs/architecture/architecture.md: QQ-18 (Flow's command result enums) → resolved by ADR-0010 Decision 2 (`Flow.StartResult`, `Flow.CallResult`)
