# ADR-0008: App Lifecycle and Battle Composition

## Status
Proposed. **Must not be marked Accepted before the phone spike (GF5) has confirmed verification items L1 to L9 below.** Items L1 to L5 and L7 decide which engine notifications the wrapper listens to; L6 decides how Retry frees the old battle; L8 decides whether the fatal screen can be trusted; L9 decides whether a broken stage scene is caught. The design is built to survive either answer where it can, but a decision that rests on a notification nobody has seen fire on a phone is a guess, not an Accepted decision.

## Date
2026-11-02

## Last Verified
2026-11-02

## Decision Makers
Lead programmer (drafted in autonomous mode), revised after the technical-director and engine-specialist reviews of 2026-11-02. The project owner decides Accepted and signs off the amendments to Accepted ADRs listed in the Migration Plan.

## Summary
One scene, `AppRoot`, is the main scene. It holds the catalogue, the fatal screen and the counters that survive Retry, drives one `wrapper.step(delta)` per frame, and builds, discards and rebuilds each battle between ticks. The `BattleWrapper` is the only owner of lifecycle states (focus, back, quit, resize), holds them until frame step 1b, and forwards them to Flow, the HUD and AppRoot.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (scene tree, application lifecycle) |
| **Layer** | Core |
| **Knowledge Risk** | HIGH: `docs/engine-reference/godot/` holds nothing on application notifications, quit handling, `free()` timing or scene loading. Every engine behaviour in this ADR is a verification item |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md` (searched for notification, quit, free and scene-load names: only `PackedScene.instance()` to `instantiate()` appears), `current-best-practices.md` |
| **Post-Cutoff APIs Used** | None known. 4.7 typed-return overrides apply to any overridden method that returns a value |
| **Verification Required** | All **NOT SOURCEABLE** from `docs/engine-reference/godot/`; each is "memory, unverified" and each is checked on the phone spike (GF5). **L1**: which of `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_APPLICATION_FOCUS_IN`, `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_RESUMED` and the window focus notifications fire on Android and on iOS for home press, app switch, lock screen, a system dialog and return (memory: FOCUS and PAUSED/RESUMED fire on mobile; not known which on which). Only the `NOTIFICATION_APPLICATION_*` focus notifications are mapped; `NOTIFICATION_WM_WINDOW_FOCUS_*` are not. **L2**: these notifications reach `_notification` of a node deep in the tree, such as the wrapper, not only the root (memory: the tree broadcasts them to all nodes). **L3**: Android back arrives as `NOTIFICATION_WM_GO_BACK_REQUEST` at the wrapper, and the project setting that stops the engine quitting on back is named `application/config/quit_on_go_back` (memory, unverified), including when a Control holds focus. **L4**: on desktop, `NOTIFICATION_WM_CLOSE_REQUEST` reaches the wrapper when `get_tree().auto_accept_quit` is false, and `get_tree().quit()` after the record write ends the process; on iOS and Android no quit notification arrives when the OS kills the app. **L5**: `Window.size_changed` on the root window fires on rotation, split screen, safe-area change and desktop drag, and how many times per drag. **L6**: `Node.free()` on a subtree from `AppRoot._process`, after `wrapper.step` returned, with no wrapper method on the stack, raises no "locked object" error; and when `queue_free()` would run instead. **L7**: whether `_process` keeps running or stops while the app is in the background on each platform, and the size of the first `delta` after return (overlaps ADR-0003 F3). **L8**: a `Label` made in code with the engine default theme and font draws on an export for both phones with no resource load, with colours, full-rect anchors and `add_theme_font_size_override` set in code (the defaults may be white on near-white, so none is trusted). **L9**: `ResourceLoader.load` on a missing or broken `scene_ref` returns `null` (and logs) without stopping the game; `PackedScene.instantiate()` returns `null` on a broken scene; and a scene whose script fails may load and instantiate without its script, so a non-null result is not enough (the root's type is checked, section 5). **L10** (low risk): `Time.get_unix_time_from_system()` returns a float and `application/run/main_scene` is the right setting name (memory, unverified). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted): `CatalogueLoader.load_manifest`, the app root holds the `Catalogue`, `StatAccessor(catalogue, on_failure)`. ADR-0002 (Accepted): signal and command names, the explicit wiring in the builder, `HaltLatch`, `Battle.dispose()`. ADR-0003 (Accepted): the frame order, `step`, the queue, `RealClock`. ADR-0004 (Proposed, revised): `Battle` built from a `BattleParts` record, `TickSlot`, the `InputAssembly` seam, `FreedCheck`. ADR-0005 (Proposed): `TickConverter` first, the system classes and their inputs. ADR-0006 (Proposed): the wrapper's layer tree, `FieldSpace` swap at step 1g, `ResumeCommand`, fatal screen on canvas layer 30. ADR-0007 (Proposed): `PointerGate.create(resolver, edge_reject_margin, clock, log_sink)`, `gate.set_input_blocked`, `gate.forget_open_presses()`, `InputAdapter` (reads in `_input` through the gate) |
| **Enables** | Every MVP epic: no system can run in the game, or be tested through the wrapper, before this composition exists |
| **Blocks** | Flow, Tower, Hero and Battle HUD stories that touch the wrapper, the fatal screen, Retry or the debug log's Fatal and quit records; the Mobile Platform ADR (device budgets) |
| **Ordering Note** | This ADR must not be Accepted before the phone spike confirms L1 to L9. ADR-0004, ADR-0005 and ADR-0006 are still Proposed: the names this ADR takes from them (`TickSlot`, `InputAssembly.build`, `TickConverter`, `ResumeCommand`, `StageFlow` handlers) move with them. ADR-0007 is also Proposed: `PointerGate`, `forget_open_presses` and the adapter move with it |

## Context

### Problem Statement
The architecture fixes what happens each frame (ADR-0003) and what each system is (ADR-0005), but not who creates them, who owns what lifetime, or what happens when the OS or a broken file interrupts. Seven gaps are open:

1. **Lifecycle had two owners.** The Input GDD gives the adapter the `lifecycle_changed` signal; Flow Rule 17 gives pause to the wrapper (finding GF6).
2. **Nothing handles quit or resize** (warning M1). Input emits them, Flow Rule 17 covers only focus loss and backgrounding, and the debug log's provisional record on quit has no writer.
3. **A broken stage scene cannot Fatal "during `build`"** (warning M2). The builder runs without a scene; the wrapper loads `scene_ref` after `build` returns; nobody is named to write the Fatal record before the views exist.
4. **`free()` timing on Retry is unverified.** Retry must free the old battle and its views at once (Flow Rule 16), yet destroying a caller is unsafe.
5. **No GDD handles the Android back button** (A10).
6. **`halted()` cannot be enforced as stated** (GF8): "check after each read" has no test.
7. **ADR-0004 and ADR-0005 each ask this ADR for a seam**: the `InputAssembly` function and the slot list, and the order in which the builder constructs systems.

### Constraints
- Flow Rule 1: the main scene is a minimal root, no autoload, no gameplay references. It holds the catalogue, the fatal screen, the launch ID, `attempt_seq` and `call_prompt_done`. Only these survive Retry.
- Flow Rule 2 and 3: the builder is a plain function that wires and holds no gameplay branch. The wrapper holds no gameplay logic.
- Flow Rules 16, 17, 18; ADR-0003 section 2: step order is fixed. Retry only sets a latch.
- ADR-0001: no autoload; `CatalogueLoader` is the only code that opens a file.
- ADR-0002 rule 7: no system holds `Battle`; `Battle.dispose()` is the backstop.
- The engine reference says nothing on lifecycle, so the design may not depend on one particular notification set.
- Single-threaded; gameplay uses no `_process`, timer, `await` or wall clock. Only AppRoot, the wrapper and views touch engine time.

### Requirements
- TR-flow-001: minimal app root, counters across Retry.
- TR-flow-002: `build` is a plain function, headless.
- TR-flow-005, 006: phase machine and the two-step outcome latch, in the composition.
- TR-flow-007: Retry rebuilds everything, from a latch, between ticks.
- TR-flow-008: pause on focus loss, resume by tap, quit and resize handled, back is Pause.
- TR-flow-009: idempotent Fatal handler, fatal screen without catalogue data.
- TR-input-007: one lifecycle owner, the wrapper.
- TR-tower-001, TR-hero-001: Sim and Input splits.

## Decision

### 1. Files and directories
The sim directories are named here, because ADR-0004's token scan covers every `.gd` file under them.

```
res://src/app/      app_root.gd, app_root.tscn (main scene), app_services.gd, fatal_relay.gd, fatal_screen.gd, real_clock.gd
res://src/sim/      battle/ (Battle, BattleBuilder, TickSlot, HaltLatch, BattleCommand and subclasses),
                    flow/, wave/, combat/, tower/, hero/, clock/ (TickConverter)      every file here is scanned
res://src/input/    input_assembly.gd, input_pieces.gd, tower_input.gd, hero_input.gd, (resolver and adapter: ADR-0007)
res://src/wrapper/  battle_wrapper.gd, lifecycle_gate.gd, views and HUD (ADR-0006)
```

`src/sim/` holds no `Node`. A new sim folder goes under `src/sim/` and so is scanned with no list to extend. `src/app/` and `src/wrapper/` are not scanned: they are the only places that may touch engine time, notifications and the tree.

### 2. The main scene and AppRoot
`app_root.tscn` is set as the main scene (`application/run/main_scene`, L10). Its root is one plain `Node` with `app_root.gd`, and its `process_mode` is `PROCESS_MODE_ALWAYS` (as is the fatal layer), so nothing that pauses a subtree can stop the latches. The scene file holds two exported values: `launch_stage_id` and `manifest_path`. There is no autoload. MVP has one stage, so `launch_stage_id` is scene data, not code; the seed is the constant `0` because waves are authored without randomness (TR-enemy-002). A reviewer checks this when a second stage arrives.

AppRoot's state is exactly this:

```gdscript
class_name AppRoot extends Node
## Main scene. Holds no gameplay reference. Survives Retry.
var _catalogue: Catalogue           # held for the whole session (ADR-0001)
var _launch_id: int                 # set once in _ready, never changes
var _attempt_seq: int = 0           # +1 at the start of each attempt, first is 1
var _call_prompt_done: bool = false # set by the HUD through AppServices
var _relay: FatalRelay              # idempotent, keeps the first cause
var _wrapper: BattleWrapper = null  # null at boot, after Fatal, and during a rebuild
var _retry_requested: bool = false
var _quit_requested: bool = false
```

`_ready` runs in this order, and the order is the fatal-scene guarantee (section 7):
1. Build the `FatalScreen` (CanvasLayer 30, hidden, built in code, section 7).
2. Create the `FatalRelay` and the `RealClock`; set `_launch_id = int(Time.get_unix_time_from_system())` (a float; L10). It is a log label, not gameplay. Assign `_quit = get_tree().quit` here, not as a member initialiser (the tree is not ready at member initialisation).
3. `CatalogueLoader.load_manifest(manifest_path, _relay.report_boot)`. A `null` return is the boot Fatal: no wrapper exists, so the root writes the Fatal record (cause `BOOT`) and shows the screen.
4. Otherwise `_start_attempt()`.

AppRoot never reads a gameplay value. It does not look inside the `Catalogue` except to pass it on.

### 3. AppServices: what the wrapper may call on the root
The wrapper and HUD get no pointer to AppRoot. AppRoot hands them one `AppServices` (`RefCounted`) at setup. AppRoot implements `request_retry()` and `set_call_prompt_done()` as methods and the `Callable` fields bind to them; those two names are the ones ADR-0002 fixes.

```gdscript
class_name AppServices extends RefCounted
var catalogue: Catalogue
var clock: RealClock
var launch_id: int
var attempt_seq: int
var request_retry: Callable          # sets AppRoot._retry_requested; the Retry handler calls only this
var call_prompt_done: Callable       # () -> bool
var set_call_prompt_done: Callable   # () -> void
var report_fatal: Callable           # (cause: String) -> void; same function as the builder's fatal_handler
var on_lifecycle: Callable           # (state: StringName) -> void; the wrapper's forward to AppRoot
```

A test passes fake callables; no `AppRoot` is needed. This keeps "systems get each other only through the builder's wiring" true one level up.

### 4. The per-frame driver and the two latches
```gdscript
func _process(delta: float) -> void:
    if _wrapper != null:
        _wrapper.step(delta)                  # ADR-0003 section 2, step 1
    if _relay.is_fatal(): _enter_fatal()      # step 2a: Fatal first (ADR-0003)
    if _quit_requested: _quit.call(); return  # step 2b
    if _retry_requested and not _fatal_shown: _retry()   # step 2c
```

This keeps ADR-0003's step 2 order: Fatal first (the Fatal record is taken there), then the quit check, then Retry. If a quit and a Fatal fall in one frame, the Fatal record is written, then the app quits. A quit request is seen and answered by the HUD in step 1b (section 6); the process ends here. `_quit` is a `Callable` assigned `get_tree().quit` in `_ready`, so a test can replace it. Nothing in step 2 runs inside a signal handler or an input callback: the latches only record that something happened, and `_process` acts on them from a clean stack.

### 5. Build order, Fatal during build, and the broken scene (M2)
**Who builds.** AppRoot calls `BattleBuilder.build`, not the wrapper. This differs from architecture 3.4 step 3 (see Migration Plan). Reason: Flow Rule 18 says that if Fatal latches during `build`, the root discards the partial battle without ticking it and writes the record, since no HUD exists. If the wrapper called `build`, the wrapper would hold a half-built battle and the root would have to reach into it. With the root building, no wrapper exists until the sim is whole.

**Builder order** (inside `BattleBuilder.build(catalogue, stage_id, seed, fatal_handler) -> Battle`, one function of explicit typed `signal.connect(callable)` lines, no gameplay branch):
1. `HaltLatch.new()`. The builder creates it and passes it to `Battle._init(latch, slots, systems)` (ADR-0004) and to each system. ADR-0002's line "Battle creates the latch" is amended to match (Migration Plan).
2. `StatAccessor.new(catalogue, on_failure)` where `on_failure` is a small closure that trips the latch, then calls `fatal_handler(cause)`. So the battle's `halted()` and the root's relay both turn on at once, in that order.
3. `TickConverter` (ADR-0005: first, so every authored duration converts through the one function).
4. `Combat`, then `WaveSim`, `TowerSim`, `HeroSim`, `StageFlow` (ADR-0005 order).
5. Every signal connection of architecture 3.2 (explicit typed connects).
6. One `TickSlot` per row of architecture 3.1, in tick order (ADR-0004).
7. Fill one `BattleParts` record (ADR-0004, revised: typed, nullable `flow`, `combat`, `wave`, `tower`, `hero`, plus `latch` and `slots`), construct `Battle` from it and return it. A system the builder could not build because a Fatal fired stays `null` in the record; `Battle` is still made, with `halted()` true. The `Battle._init(latch, slots, systems)` form named earlier in this ADR's sources is read as this record.

The `GestureResolver` is no longer made by `build`. ADR-0004's `InputAssembly` makes it (section 8), so the headless builder holds no input object and the wrapper test and the bot path share one input wiring.

**Fatal during build.** GDScript has no exceptions, so `build` always runs to its last line and always returns a `Battle`, whose `halted()` is true if the handler fired. `build` never returns `null`. The caller checks. AppRoot's `_start_attempt`:

```gdscript
func _start_attempt() -> void:
    _attempt_seq += 1
    var services := _make_services()
    var battle := BattleBuilder.build(_catalogue, launch_stage_id, 0, _relay.report)
    if battle.halted() or _relay.is_fatal():
        _fatal_before_views(battle, "build"); return
    var wrapper := BattleWrapper.new()
    wrapper.configure(battle, services)
    if not wrapper.prepare():                  # loads the stage scene; no node is in the tree yet
        _fatal_before_views(battle, "scene", wrapper); return
    add_child(wrapper)
    wrapper.attach()                           # input pieces, gate, adapter, views, HUD, then phase(Build)
    _wrapper = wrapper
    get_tree().auto_accept_quit = false        # a wrapper now owns quit (section 6)
```

The wrapper's `_ready` does not depend on `attach()`: it only creates the lifecycle gate. `auto_accept_quit` is set to `true` explicitly in `_fatal_before_views`, in `_enter_fatal` and at the start of `_retry`, so a path that ends with no wrapper never leaves the engine unable to quit.

`_fatal_before_views(battle, stage, wrapper)` is the single path for every Fatal that latches before any view exists. It calls `battle.dispose()`, frees the unattached wrapper if there is one, writes the Fatal record through an injected `FatalRecordWriter` callable (fields: `launch_id`, `attempt_seq`, `cause`, `stage` one of `boot`, `build`, `scene`), and enters Fatal. It reads nothing else from the battle (Flow Rule 18).

**Broken stage scene (M2).** `wrapper.prepare()` is the first wrapper call and the only runtime scene load. It reads `scene_ref` from the stage record through the battle's accessor path, calls `ResourceLoader.load`, checks that the result is a `PackedScene`, calls `instantiate()`, and checks that the result is not `null` **and** that its root is the stage script class (`is StageScene`), because a scene whose script fails may load without its script (L9). On any failure it calls `services.report_fatal("SCENE")` and returns `false`. The wrapper is not in the tree, has no adapter and no views, and `phase(Build)` has not been emitted. So the broken scene takes exactly the build-failure path: the root writes the record, discards the battle and shows the fatal screen. The answer to M2 is that the load is moved to before the views connect and joins the root-written path, and the scene load stays a Fatal source of the wrapper (architecture 3.6, three runtime sources).

**`phase(Build)`.** After `attach()` has connected all views, the wrapper calls the single `StageFlow` method that emits `phase(Build)` once for a built battle (named `announce_build()` here; ADR-0005 owns the final name and ADR-0004's `BattleRig.make` calls the same one). `build` never calls it (Flow Rule 6). It is not called when any Fatal latched before the views connected.

### 6. BattleWrapper: lifecycle, quit, resize and back
The wrapper is the only lifecycle owner (GF6). The input adapter has no lifecycle state; it reports a touch cancel to the resolver and nothing more (architecture 4.2).

**Holding.** `LifecycleGate` (a `RefCounted` held by the wrapper, so it can be tested without a node) receives raw engine events from the wrapper's `_notification` and its connection to the root window's `size_changed`. It turns them into the five canonical states and holds them in an ordered array. Nothing happens in the notification callback except that append. The five states are the existing ones: `focus_lost`, `focus_gained`, `quit_requested`, `resized`, `back`.

**De-duplication, so the design does not depend on L1.** The gate keeps `_focused: bool` (true at attach). Any of the focus-out or paused notifications sets focus false and appends `focus_lost` only on a true-to-false change; any focus-in or resumed notification appends `focus_gained` only on false-to-true. If a platform sends both FOCUS_OUT and PAUSED on a home press, one `focus_lost` results; if it sends only one, one results. The set of notifications mapped is the single table in `lifecycle_gate.gd`; the spike edits that table, not the design.

**Forwarding, in step 1b.** At step 1b of `wrapper.step`, before `apply_queued()`, the wrapper first discards queued resumes when a held state is `focus_lost`, `back` or `quit_requested`: `battle.discard_queued(&"resume")` (each `ResumeCommand` gets `on_result` DISCARDED and is logged), so a resume tap queued in the same frame cannot unpause a game that has just been backgrounded. Then it emits `lifecycle_changed(state)` for each held state in arrival order and clears the array. The wrapper's own signal reaches Flow and the HUD; the forward to AppRoot is the one callable `services.on_lifecycle(state)`, which is not a signal connection. Held states survive a frame where the app is suspended: if `_process` stops in the background (L7), the states wait and run first on return, in order, while the clock is still stopped.

**What each state does.**

| State | StageFlow | HUD | Wrapper | AppRoot |
|---|---|---|---|---|
| `focus_lost` | enters Paused if in Build, Wave or Intermission; no effect in Paused or a terminal state (Flow Rule 17) | none | requests `cancel()` | none |
| `focus_gained` | none: Paused ends only by the resume tap (`ResumeCommand`, ADR-0006) | none | none | none |
| `back` | same as `focus_lost` (A10): Pause in a battle; no effect in Paused, Won or Lost, so back never exits the battle | none | requests `cancel()` | none |
| `resized` | none (does not pause) | re-lays out | requests `cancel()`; at step 1g runs `resolver.cancel()`, then `gate.forget_open_presses()` (ADR-0007), then `set_space` with the new `FieldSpace` (ADR-0006), in that order | none |
| `quit_requested` | none | writes the provisional debug record now, in its handler | none | sets `_quit_requested`; the end-of-frame check calls `quit()` |

**Quit (M1).** The quit waits for the write because the write is a synchronous call inside the HUD's `lifecycle_changed` handler, which runs in step 1b, and the quit runs at AppRoot step 2b, after `step` returned and after any Fatal in the same frame has been handled. While a wrapper exists, AppRoot sets `auto_accept_quit = false` so the engine does not quit before the record is written (L4). With no wrapper (boot, after Fatal, during a rebuild) it sets the value back to true, so the engine's default quit works and no second lifecycle owner exists. The one thing AppRoot does with no wrapper is treat a back request as a quit, because the project setting that keeps the engine from quitting on back (L3) would otherwise leave the fatal screen with no way out on Android.

**Resize (M1).** `resized` does not pause. A desktop window drag would otherwise pause the stage on every frame of the drag; on a phone, a resize follows rotation, split screen or a safe-area change, and the gesture in flight is cancelled by the existing `cancel()` request (ADR-0006 section 4). Flow Rule 17 lists "losing focus or backgrounding" only, so this is consistent with the rule and a GDD line states it (Migration Plan). A reviewer should check this choice: the alternative is to pause on resize, which is simpler to explain and worse to play.

**Pause semantics and `ResumeCommand` (owned here; ADR-0006 keeps only the input route).**
- Entering Paused: `focus_lost` or `back`, from Build, Wave or Intermission. Flow stores the phase it left (`_resume_to`, one of those three) and stops the clock.
- Leaving Paused: only by a queued `ResumeCommand` (a `BattleCommand` subclass, no args, `to_record` kind `resume`) from the resume tap on PausedScreen. `focus_gained` never resumes by itself (Flow Rule 17: a tap resumes). `back` while Paused changes nothing and does not resume.
- `StageFlow.resume() -> int` returns `OK` (Paused ended: Flow emits `phase(_resume_to)`, restarts the clock, and the HUD does not treat it as a new appearance, HUD Rule 11), `HALTED` (the battle is halted: nothing changes) or `NOT_PAUSED` (nothing changes; a double tap lands here). `ResumeCommand.apply` returns that code through the same result path as the other commands and ends in an explicit `return` (4.7 typed-return rule). The accumulator is already zero because the clock was stopped (ADR-0003 section 3).
- Because it is a queued command, a resume tap is logged and replays like every other command (`command_log`).

**Pause is a Flow state, not the tree's pause.** The clock stops (Flow Rule 17) and `get_tree().paused` stays false, because the tree pause would also stop AppRoot, the lifecycle gate and the modal screens, all of which must keep running while Paused. The wrapper zeroes the tick accumulator whenever the clock is stopped (ADR-0003 section 3), so no time jump follows resume.

### 7. The fatal scene guarantee
The fatal screen must load when the catalogue, a stage scene or a theme file is the thing that failed. It is therefore built in code in `_ready` step 1, before the catalogue load, from a `CanvasLayer` (layer 30, `PROCESS_MODE_ALWAYS`) holding one `ColorRect` and one `Label` made with `.new()`. Both are anchored full-rect in code. The `ColorRect` colour is dark and the `Label` colour is light, both set in code, and the text size is set with `add_theme_font_size_override`, because default colours may give white text on a near-white ground. It loads no file: no scene, no font, no texture, no string table, no catalogue data. It uses the engine default theme and font (L8). Its text is a fixed generic message, the launch ID and a cause code from a closed set (`BOOT`, `BUILD`, `SCENE`, `READ`).

The screen lives in AppRoot, not in the HUD or the wrapper tree, and the HUD never mounts it. Its `ColorRect` has `mouse_filter = STOP`, and `_enter_fatal` calls the wrapper's `shutdown()` before the wrapper is freed, which sets `gate.set_input_blocked(true)` (ADR-0007), so no gesture reaches a dying battle and none reaches anything under the screen afterwards.

The screen is absorbing. `_enter_fatal` (at step 2b) does, in order: if a wrapper exists and its views were connected, the HUD has already written the Fatal record from reads held at the latch (Flow Rule 18, steps d and f2 of the frame); otherwise the root writes it; then the wrapper is shut down and freed as in section 9, `_wrapper = null`, `auto_accept_quit = true`, and the screen is shown. The Retry latch is ignored from then on, there is no button, and the process stays alive only until the OS or the player ends it. `_enter_fatal` is idempotent, because the relay keeps the first cause and `_wrapper` is already null the second time.

`FatalRelay.report(cause: String)` is the one `fatal_handler`. It keeps the first cause, ignores later calls, and has no dependency on the battle. The builder's closure trips the battle's latch first (section 5), so the order "battle latched, then root latched" holds on every path.

### 8. The Sim and Input splits, and the `InputAssembly` seam (A2)
`TowerSim` and `HeroSim` are pure, built by `build`, and listed in `systems()`. `TowerInput` and `HeroInput` are `RefCounted` objects in `src/input/`, absent from `build`, made only by `InputAssembly`:

```gdscript
class_name InputAssembly extends RefCounted
## Builds the input pieces and their connections. Loads no stage scene, makes no
## InputAdapter and no view. The wrapper and the tests call this same function.
static func build(battle: Battle, catalogue: Catalogue, clock: RealClock) -> InputPieces

class_name InputPieces extends RefCounted
var resolver: GestureResolver       # built here with the Input record, ADR-0007
var hero_input: HeroInput
var tower_input: TowerInput
```

`InputAssembly.build` makes the resolver, registers `HeroInput` and `TowerInput` with it, connects `flow.phase` to `TowerInput` (the chip), and connects the resolver's signals to the two input objects. Both input objects queue commands with `battle.enqueue` and read the sim through the typed reads; neither holds the `Battle` reference beyond construction. `TowerInput` emits `slot_tapped`, `tower_inspected` and `upgrade_refused` (wrapper only, ADR-0002); `WiringCheck.wrapper` covers them.

`InputAssembly` is the wrapper's own wiring, delegated to one function: only `BattleWrapper.attach()` and tests call it. ADR-0002 rule 1 (the builder and the wrapper are the two places that connect) therefore still holds, and no amendment is needed. `attach()` builds in this order: resolver, `HeroInput`, `TowerInput` (the three through `InputAssembly.build`), then `PointerGate.create(resolver, catalogue.input().edge_reject_margin, clock, log_sink)` with `log_sink` taken from the debug log in debug builds and a no-op otherwise, then `InputAdapter`, then the views and HUD. Headless callers never call it, except the hero equivalence test.

### 9. Retry: stop, cancel, dispose, free, rebuild
`_retry()` runs at step 2c, from the latch, outside any signal and any input call:

```gdscript
func _retry() -> void:
    _retry_requested = false
    var old := _wrapper
    _wrapper = null
    get_tree().auto_accept_quit = true   # no wrapper until _start_attempt returns
    old.shutdown()          # cancel input, block input, disconnect, battle.dispose(), drop references
    remove_child(old)       # out of the tree at once: no frame, input or notification reaches it
    old.free()              # immediate (L6); fallback below
    _start_attempt()        # attempt_seq + 1, new battle, new wrapper, new everything
```

`wrapper.shutdown()` does, in this order: `resolver.cancel()` inline (the clock is already irrelevant, since nothing will tick this battle again); `gate.forget_open_presses()`; `gate.set_input_blocked(true)`; disconnect the wrapper's own engine connections (the window `size_changed`); `battle.dispose()` (ADR-0002: disconnect every system and clear the list; idempotent); set `_battle`, the pieces and every held view reference to `null`. Then the root takes the wrapper out of the tree and frees it. Every view's `_exit_tree` must cope with references that `shutdown()` already set to `null`.

**`free()` timing.** The decision is `remove_child` then immediate `free()`. It is safe by call stack: the wrapper's `step` has returned, the Retry handler that set the latch ended frames ago, and the only caller on the stack is AppRoot's own `_process`. The wrapper is the one node whose subtree must not be freed from inside its own callbacks, and it is not in any. An immediate free also means no input, notification or view `_process` can reach the old battle after the latch, and only one battle exists in memory at a time. **If L6 shows that `free()` here errors or leaves orphans, the fallback is `queue_free()`** after `remove_child`, `set_input_blocked(true)` and `shutdown()`, all of which already ran; the old tree is then unreachable for the rest of the frame, and the cost is one extra frame of memory. The Retry freed test (ADR-0004 section 9) runs one frame later in that case. Nothing else in this ADR changes with the answer.

**What survives.** AppRoot, `_launch_id`, `_attempt_seq`, `_call_prompt_done`, the `Catalogue`, the relay, the `RealClock`, the fatal screen. `_attempt_seq` increases at the start of every `_start_attempt`, so a Retry that ends in Fatal still shows the right attempt number in the record. A retried battle opens in Build and emits `phase(Build)` once, after its new views connect (Flow Rule 16).

### 10. `halted()` rules (GF8)
- The tick loop in `Battle.tick` checks `halted()` before the first slot and at every slot edge (ADR-0003 section 3).
- Every system checks `halted()` before it emits a signal. An emit after Fatal is a defect that a test finds by tripping the latch and asserting a `SignalTap` records nothing.
- No system checks `halted()` after each read. The `StatAccessor` returns a typed zero after Fatal (`0`, `0.0`), so the calling function finishes safely.
- Runtime Fatal has three sources only: the `StatAccessor` (a bad read), `BattleBuilder.build`, and the wrapper's `prepare()` scene load. Catalogue load failure is a boot Fatal before any battle. `FatalRelay.report` is the one entry for all four.
- A Fatal latched outside a tick takes the same second step at the end of the frame (ADR-0003 steps d and f2).

## Alternatives Considered

### Alternative 1: The wrapper calls `BattleBuilder.build` (architecture 3.4 as written)
- **Description**: The main scene creates a wrapper; the wrapper builds the battle, loads the scene and handles its own Fatal.
- **Pros**: One object owns the battle from creation. AppRoot is thinner.
- **Cons**: A Fatal during `build` leaves the wrapper holding a partial battle, and Flow Rules 1 and 18 say the root discards it and writes the record. The wrapper would have to report to the root and then be freed by it, a caller deciding its own removal. Two paths for a Fatal before the views.
- **Rejection Reason**: One path for every Fatal before the views is simpler to test (M2).

### Alternative 2: Replace the scene for Retry with `change_scene_to_packed`
- **Description**: Treat each attempt as a scene change and let the engine free the old one.
- **Pros**: Uses the engine's own teardown; no hand-written free.
- **Cons**: The engine frees the old scene at a time this ADR cannot source and does not control; AppRoot would be freed with it, so the catalogue, launch ID and counters would need an autoload or a static, both forbidden (ADR-0001, Flow Rule 1). Frame order after the swap is also unsourced.
- **Rejection Reason**: Conflicts with no autoload and with the counters surviving Retry.

### Alternative 3: Pause with `get_tree().paused`
- **Description**: Flow's Paused also sets the tree's pause flag.
- **Pros**: Views and animations freeze for free.
- **Cons**: It also freezes the lifecycle gate, AppRoot and the modal Paused screen unless each is given an always-run mode; a second pause mechanism beside Flow's clock.
- **Rejection Reason**: Two pause states can disagree. Flow's clock is the one pause.

### Alternative 4: Pause on resize
- **Description**: Treat `resized` as another focus loss.
- **Pros**: Simple rule: anything odd pauses.
- **Cons**: A desktop drag pauses every frame; a rotation on a phone pauses and needs a tap for no reason the player can see.
- **Rejection Reason**: The gesture cancel plus a layout rebuild is all a resize needs.

### Alternative 5: Keep the adapter as a lifecycle owner as well
- **Description**: The adapter forwards focus and back; the wrapper keeps pause.
- **Pros**: Matches the Input GDD text as it stands.
- **Cons**: Two owners was finding GF6.
- **Rejection Reason**: One owner (GF6).

## Consequences

### Positive
- One path for every Fatal that latches before the views exist, tested by two cases (build, scene).
- The fatal screen depends on no file, so a bad catalogue or a bad scene cannot stop it from showing.
- The wrapper, the bots and the equivalence test use one input wiring (`InputAssembly.build`).
- Lifecycle has one owner and a held, ordered queue, so the frame order never depends on when the OS calls the app.
- The design needs no particular notification: the gate de-duplicates and the spike edits a table.

### Negative
- AppRoot is more than a stub: it owns build, discard, Retry and the quit check. It stays free of gameplay values, but it is the busiest non-sim file.
- Architecture 3.4 and 4.3 change (Migration Plan).
- Quit, resize and back choices add rules to the Flow and Input GDDs.
- The back button never leaves a battle; the player leaves with the OS.
- If `free()` must fall back to `queue_free()`, a Retry frame briefly holds two scene copies.

## Risks
- **A notification this ADR relies on does not reach the wrapper (L1, L2).** Mitigation: the gate's table is the one place to change; if the wrapper does not receive them, AppRoot forwards the same raw events into the gate through `services`. The wrapper stays the owner of the states.
- **Android back is consumed by the engine and quits the app (L3).** Mitigation: the setting is a one-line project change; the spike confirms it. Until then, back may quit.
- **`free()` raises an error (L6).** Mitigation: the `queue_free()` fallback above.
- **A Retry frame is long** (build, scene instantiate and view build in one frame). Mitigation: proposed budget 200 ms on the target phone; the spike measures it; if it fails, the rebuild splits across two frames behind a held "retrying" state, which is a change to this ADR.
- **The fatal screen text does not draw on an export (L8).** Mitigation: it then shows as a solid colour, and the cause is in the debug log; a bundled font is a later change with a written reason.
- **A Fatal and a quit in the same frame.** Fatal is handled first (the record is written), then the app quits.
- **A resume tap queued in the same frame as a focus loss.** Step 1b discards queued resumes first (section 6), so the game stays Paused.
- **Focus is lost during the rebuild frame.** The new gate starts with `_focused = true`; the next notification corrects it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-state-stage-flow.md Rule 1 (TR-flow-001) | Minimal root, no autoload, catalogue, fatal screen, launch ID, `attempt_seq`, `call_prompt_done` | Section 2 and 3: AppRoot state list, `AppServices`, nothing else survives Retry |
| game-state-stage-flow.md Rule 2, 3 (TR-flow-002) | Plain builder, no scene, no gameplay branch in builder or wrapper | Section 5: seven-step builder, returns a `Battle`, no scene, no branch on a gameplay value |
| game-state-stage-flow.md Rule 6, 15 (TR-flow-005) | `phase` on every change, `phase(Build)` once per built battle | Section 5: root builds, `announce_build()` after views connect, never on a pre-view Fatal |
| game-state-stage-flow.md Rule 15, 18 (TR-flow-006) | Outcome latches in two steps | Section 4 and 10: steps d and f2 stay (ADR-0003), root step 2 after them; tick loop and emitters check `halted()` |
| game-state-stage-flow.md Rule 16 (TR-flow-007) | Retry rebuilds everything from a latch between ticks | Section 9: `_retry` at step 2c, shutdown, `remove_child`, `free()`, rebuild |
| game-state-stage-flow.md Rule 17 (TR-flow-008) | Pause on focus loss, tap resumes, accumulator zero; quit and resize (M1); back is Pause (A10) | Section 6: gate, table of states, quit writes then exits, resize cancels without pausing, back pauses |
| game-state-stage-flow.md Rule 1, 18 (TR-flow-009) | Idempotent Fatal handler; fatal screen with no catalogue data | Section 7: `FatalRelay`, screen built in code before the load |
| input-gesture-resolver.md (TR-input-007) | `lifecycle_changed` covers five states, one owner is the wrapper | Section 6: the wrapper holds and forwards; the adapter owns none |
| tower-system.md (TR-tower-001) | TowerSim and TowerInput are separate | Section 8: `build` makes TowerSim; `InputAssembly` makes TowerInput |
| hero-system.md (TR-hero-001) | HeroSim and HeroInput are separate | Section 8, the same |
| battle-hud.md Rule 18, 19 | Retry only sets a latch; Fatal and provisional records | Section 3 (`request_retry`), 5 and 6 (who writes the Fatal record, quit waits for the write) |

## Performance Implications
- **CPU**: The per-frame cost this ADR adds is a few checks in `_process` and the held-state drain. A Retry frame does build, scene instantiate and view build once; proposed budget 200 ms on the target phone, measured by the spike.
- **Memory**: With immediate `free()` one battle exists at a time. With the `queue_free()` fallback two scene copies exist for one frame.
- **Load Time**: The catalogue load and first build run in `_ready`. No figure is sourced; the Mobile Platform ADR sets device budgets.
- **Network**: None.

## Migration Plan
No code exists yet. These edits land in the same change that marks this ADR Accepted.

**Amendments to Accepted ADRs, for the user's sign-off at acceptance.** Each of these changes an Accepted ADR or a registry stance, so the user signs them off when marking this ADR Accepted:
- ADR-0002 rule 7 (line 67): the builder, not `Battle`, creates the `HaltLatch`, because the `StatAccessor` needs it before `Battle` exists. ADR-0002's canonical command table gains a `ResumeCommand` row and `StageFlow.resume() -> int` (`OK`, `HALTED`, `NOT_PAUSED`). Its `lifecycle_changed` row gains the AppRoot recipient (`AppServices.on_lifecycle`, a callable) and the note that `resized` does not pause.
- ADR-0003: the "five subclasses" list (and architecture 4.3 line 444) gains `ResumeCommand` as the sixth; step 1g of the frame gains `gate.forget_open_presses()` between `resolver.cancel()` and the `FieldSpace` swap; line 76 loses "(ADR-0008 confirms)". Step 2 order (Fatal, then Retry) is unchanged; the quit check sits between them.
- Registry stances that change: the `HaltLatch` creator, the `ResumeCommand` entry, and a new lifecycle-owner stance (the wrapper) if the registry words it as the adapter.
- `InputAssembly` needs no amendment: it is the wrapper's own wiring (section 8), so ADR-0002 rule 1 holds.

Other edits that follow from this ADR:

1. `docs/architecture/architecture.md` Data Flow 3.4 (lines 309 to 322): step 3 becomes "AppRoot calls `BattleBuilder.build`; the wrapper's `prepare()` loads the stage scene, then `attach()`"; item 3a (architecture 3.4a) drops `GestureResolver` (built by the wrapper through `InputAssembly`, not by the battle builder) and adds `HaltLatch`, `StatAccessor` and `TickConverter` first; step 4 names who calls the `phase(Build)` method.
2. Same file, 3.5 (lines 324 to 329): replace "The timing of `free()` is unverified (ADR-0008)" with the section 9 sequence and its L6 fallback.
3. Same file, 3.1 diagram line 272: "AppRoot end of frame: Fatal latch first, then the quit check, then the Retry latch".
4. Same file, 4.3 (lines 427 to 473): the `build` comment says it returns a `Battle` built from a `BattleParts` record that may be halted and is never `null`; the builder creates the `HaltLatch`. Section 3.4 (and 3.4a) are rewritten as item 1 says, since AppRoot is the battle builder.
5. Same file: Gate Findings GF6 and GF8 (lines 34, 36) become "Confirmed, ADR-0008"; Open Questions M1, M2 (lines 729, 730), A2 (741) and A10 (749) close; the Required ADRs row for ADR-0008 (line 687) is marked Done; the Document Status line 15 is brought up to date; the 3.2 table row for `lifecycle_changed` (line 296) records that the forward to AppRoot is `AppServices.on_lifecycle`, not a signal connection, and that `resized` does not pause.
7. `design/gdd/game-state-stage-flow.md`: Rule 1 (the root builds the battle and writes the Fatal record for every Fatal before the views connect, including the stage scene load); Rule 17 (add Android back as Pause, quit requested, and resized as a cancel without a pause); Rule 18 ("a broken stage scene" reaches the root path through `prepare()`); the line 71 text that the wrapper emits five states stands; line 75 "Becomes an ADR" is marked done.
8. `design/gdd/input-gesture-resolver.md` (lines 66 and 123): `lifecycle_changed` is emitted by the wrapper, not the adapter. `design/gdd/battle-hud.md`: add the Android back rule (A10); the provisional record is written in the HUD's `lifecycle_changed` handler on `quit_requested`; the Fatal record before the views exist is the root's (near line 106 and Rule 19).
9. `docs/architecture/adr-0004-headless-battle-harness-and-snapshot.md`: line 242 requirement is met by `InputAssembly.build(battle, catalogue, clock)` and the line 224 sim directories are named in section 1 above.
10. `docs/registry/architecture.yaml` and `tr-registry.yaml`: the entries listed in the registry candidates of this ADR's author report, written at Accepted.

## Validation Criteria
1. **Build Fatal.** A fixture catalogue that trips the accessor during `build` gives a `Battle` with `halted()` true; AppRoot (with fakes) writes one record with stage `build`, shows the screen, creates no wrapper and ticks nothing.
2. **Scene Fatal.** A `scene_ref` that does not load makes `prepare()` return `false`; the same single path runs with stage `scene`; no `phase(Build)` is emitted (Flow criterion 16 counts it exactly once on success).
3. **Boot Fatal.** A failing manifest shows the screen with no catalogue data and no wrapper.
4. **Retry.** After a Retry the weakref check over the old battle, every system and every wrapper node is empty (ADR-0004 section 9, extended to nodes); `attempt_seq` is one higher; `launch_id`, `call_prompt_done` and the catalogue are unchanged; the new battle opens in Build with one `phase(Build)`.
5. **Retry ordering.** A test spy proves `_retry` ran with no wrapper method and no signal on the stack, and that Fatal wins when both latches are set. With Fatal and quit in one frame, the Fatal record is written before the fake `_quit` runs.
6. **Lifecycle.** The gate test feeds duplicate and reordered raw events and asserts one `focus_lost`, one `focus_gained`, order kept; `back` in Build, Wave and Intermission pauses; `back` in Paused, Won, Lost changes nothing; `resized` requests `cancel()` and does not pause; held states emit in step 1b before `apply_queued()`.
7. **Quit.** With `quit_requested`, the HUD fake records its write before the fake `_quit` runs, in the same frame.
8. **Wiring.** `WiringCheck.wrapper` passes for the resolver, `TowerInput`, `HeroInput` and the wrapper; the hero equivalence test (ADR-0004 section 11) calls the same `InputAssembly.build`.
9. **Phone spike.** L1 to L9 are answered with logs from an Android and an iOS device, and a Retry frame is under the proposed 200 ms.
10. **Evidence.** A retained screenshot of the fatal screen on each phone in `production/qa/evidence/`.

## Related
- ADR-0001, ADR-0002, ADR-0003 (Accepted); ADR-0004, ADR-0005, ADR-0006 (Proposed); ADR-0007 (parallel).
- `docs/architecture/architecture.md`: Module Ownership rule 7, Data Flow 3.1, 3.2, 3.4, 3.5, 3.6, API Boundaries 4.2 and 4.3; Gate Findings GF6, GF8; Open Questions M1, M2, A2, A10.
- `design/gdd/game-state-stage-flow.md` Rules 1, 2, 3, 6, 15, 16, 17, 18; `design/gdd/gdd-cross-review-2026-11-02j.md` M1, M2.
