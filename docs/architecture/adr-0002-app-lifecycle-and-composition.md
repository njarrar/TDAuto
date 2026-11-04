# ADR-0002: App Lifecycle and Composition

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

Godot specialist (author, autonomous run). TD-ADR: not run per ADR; batch review after all ADRs are written. Engine specialist gate: not run per ADR; same batch review.

## Summary

TowerRiot needs one place that starts the game, builds and rebuilds a battle, reacts to the app losing focus, and shows a fatal screen, without autoloads. AppRoot, the main scene, is that place: it loads the catalogue, calls `BattleBuilder` and `ShellBuilder`, is the single receiver of lifecycle notifications, pauses through FlowSim's own Paused phase (not the engine's tree pause), and handles Retry and Fatal through latches checked in its frame.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (4.7.2 installed, matches the pin) |
| **Domain** | Core |
| **Layer** | Foundation (the architecture lists it with the Foundation ADRs; the modules it governs sit in the Composition tier, which has no Layer value of its own) |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; official class reference at tag 4.7.2-stable: `doc/classes/Node.xml`, `doc/classes/MainLoop.xml`, `doc/classes/SceneTree.xml`, `doc/classes/Object.xml`, `doc/classes/OS.xml`, `doc/classes/ProjectSettings.xml`, `doc/classes/Input.xml` |
| **Post-Cutoff APIs Used** | None directly. Relies on ADR-0001's `@abstract` `BattleReadModel` |
| **Verification Required** | Device runs listed under NOT SOURCEABLE, on Android, iOS and desktop export and in the editor |

### Sourced engine facts

| Claim | Source |
|---|---|
| `NOTIFICATION_APPLICATION_FOCUS_OUT` (2017) is sent when focus moves from any Godot window to the desktop or another app; implemented on desktop and mobile | doc/classes/Node.xml@4.7.2-stable and doc/classes/MainLoop.xml@4.7.2-stable, `NOTIFICATION_APPLICATION_FOCUS_OUT` |
| `NOTIFICATION_APPLICATION_FOCUS_IN` (2016), same scope | same files, `NOTIFICATION_APPLICATION_FOCUS_IN` |
| `NOTIFICATION_APPLICATION_PAUSED` (2015) and `NOTIFICATION_APPLICATION_RESUMED` (2014) are specific to Android and iOS; on iOS a task started by PAUSED has about 5 seconds | same files, `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_RESUMED` |
| `NOTIFICATION_WM_WINDOW_FOCUS_OUT` (1005) also fires on focus moves between two windows of the same instance | doc/classes/Node.xml@4.7.2-stable, `NOTIFICATION_WM_WINDOW_FOCUS_OUT` |
| `NOTIFICATION_WM_GO_BACK_REQUEST` is Android only; `SceneTree.quit_on_go_back` defaults to `true` | doc/classes/Node.xml@4.7.2-stable, `NOTIFICATION_WM_GO_BACK_REQUEST`; doc/classes/SceneTree.xml@4.7.2-stable, `quit_on_go_back` |
| `SceneTree.paused` stops physics and, depending on `process_mode`, `_process`, `_physics_process` and `_input` | doc/classes/SceneTree.xml@4.7.2-stable, `paused` |
| A `PROCESS_MODE_PAUSABLE` node processes and receives input callbacks while `SceneTree.paused` is false | doc/classes/Node.xml@4.7.2-stable, `can_process`, `PROCESS_MODE_PAUSABLE` |
| `_ready` runs children first, then the parent | doc/classes/Node.xml@4.7.2-stable, class description and `_ready` |
| `queue_free` deletes at the end of the current frame, after other deferred calls; safe to call more than once; children go too | doc/classes/Node.xml@4.7.2-stable, `queue_free` |
| `Object.free` deletes at once; `is_instance_valid` is false afterwards | doc/classes/Object.xml@4.7.2-stable, `free` |
| `OS.has_feature("editor")` is true in the editor and when running from it, false in an export | doc/classes/Engine.xml@4.7.2-stable, `is_editor_hint` (Note) |
| `OS.is_debug_build()` is true in the editor and debug templates | doc/classes/OS.xml@4.7.2-stable, `is_debug_build` |
| `_process` runs after the frame's physics ticks and before rendering | doc/classes/Node.xml@4.7.2-stable, `_process` |
| With `input_devices/buffering/agile_event_flushing` false (default), touch events are flushed once per process frame, between engine iterations; when true (Android only) they are flushed before every idle and physics frame | doc/classes/ProjectSettings.xml@4.7.2-stable, `input_devices/buffering/agile_event_flushing` |
| Input accumulation is on by default and merges similar events per frame | doc/classes/Input.xml@4.7.2-stable, `use_accumulated_input` |

### NOT SOURCEABLE (blocks Acceptance)

- NOT SOURCEABLE: whether `NOTIFICATION_APPLICATION_FOCUS_OUT` and `NOTIFICATION_APPLICATION_PAUSED` reach a non-root node such as AppRoot through `_notification`, or only the `MainLoop` and the root `Window`; needs a device run on Android, iOS and desktop.
- NOT SOURCEABLE: the order of FOCUS_OUT and PAUSED when a phone app is backgrounded, and whether both always fire; needs a device run.
- NOT SOURCEABLE: whether FOCUS_OUT fires when the developer clicks the editor's debugger or another editor panel while the game runs (embedded and separate window); needs an editor run.
- NOT SOURCEABLE: whether input events flushed in a frame are always dispatched before that frame's `_process` on iOS and desktop (the reference states it for the flush point, not for dispatch order against `_process`); needs a device run that logs the order (HUD Rule 18).
- NOT SOURCEABLE: whether nodes freed by `queue_free` still receive a `_process` or `_input` call later in the same frame; needs a device run. The design avoids depending on it (see Decision 6).
- NOT SOURCEABLE: whether the platform notification arrives inside a frame between input and `_process`, or outside the frame; needs a device run. Pause is idempotent and the tick guard makes either order safe, but the run must confirm no tick runs after `pause()`.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (sim and shell boundary, Composition tier) |
| **Enables** | ADR-0004 (catalogue load sits in boot), ADR-0005 (commands on `Battle`), ADR-0006 (adapter `cancel()` and Paused input), ADR-0014 (log ownership at teardown) |
| **Blocks** | Game State & Stage Flow epic (boot, Retry, Pause, Fatal stories); any story that runs the game on a device |
| **Ordering Note** | ADR-0003 sets the clock that AppRoot resets; write and accept them together |

## Context

### Problem Statement

The game has no autoload and no scene-owned battle, so something must own the catalogue, build the battle and its shell, rebuild them on Retry, stop the game when the phone backgrounds it, and show a fatal screen when content is bad. The design leaves open which notification means "paused", whether pause uses the engine's tree pause, and how a developer avoids pausing on every editor click (QQ-01).

### Current State

No code exists. `project.godot` sets no stretch, pause or input keys.

### Constraints

- No autoload (TR-flow-001). AppRoot is the main scene.
- The battle must be destroyed and rebuilt on Retry with the same seed (TR-flow-007).
- Commands apply only between ticks (TR-hud-003, ADR-0003).
- A fatal stops all ticking in the same tick and shows a screen with no catalogue data (TR-flow-009, TR-data-007).

### Requirements

- One receiver for lifecycle notifications.
- Focus loss enters Paused: clock stops, input cancels, accumulator zeroed, a tap resumes (TR-flow-008).
- The InputAdapter keeps receiving events while Paused (TR-input-003).
- Prompt flags survive Retry and reset on app restart (TR-hud-009).

## Decision

1. **AppRoot is the main scene** (`application/run/main_scene`), a `Node` with no autoload. It owns the Ready catalogue, the Retry latch, the Fatal latch, the FatalScreen, the session flags (`pinned_once`, `built_once`, `won_once`) and the Retry-to-Start timer.
2. **Boot, in `AppRoot._ready`**: load and validate the catalogue (ADR-0004); on failure show FatalScreen and stop. Else `BattleBuilder.build(catalogue, stage_id, seed, fatal_handler)`, then `ShellBuilder.build(battle, catalogue, session_flags)`. The shell is built only after the battle is whole. Children's `_ready` runs before AppRoot's (Node.xml), so AppRoot must not depend on child nodes it creates later; ShellBuilder creates the shell nodes and adds them as AppRoot children.
3. **Pause uses FlowSim's Paused phase, not `SceneTree.paused`.** `Battle.pause()` moves FlowSim to PAUSED; `Battle.tick()` returns at once while Paused; the BattleWrapper calls `FixedStepClock.reset()`. The tree is never paused, so every shell node stays `PROCESS_MODE_INHERIT` (root default PAUSABLE) and keeps receiving input and `_process` (Node.xml, `can_process`). This closes the adapter `process_mode` question: no `PROCESS_MODE_ALWAYS` is needed.
4. **Lifecycle notifications.** AppRoot overrides `_notification` and is the only node that handles lifecycle notifications:
   - `NOTIFICATION_APPLICATION_FOCUS_OUT` and `NOTIFICATION_APPLICATION_PAUSED` each call `adapter.cancel()` then `battle.pause()`. Both are idempotent, so receiving both is safe.
   - `NOTIFICATION_APPLICATION_FOCUS_IN` and `NOTIFICATION_APPLICATION_RESUMED` do nothing. Only a tap on the Paused screen calls `battle.resume()`.
   - `NOTIFICATION_WM_WINDOW_FOCUS_OUT` is not used, because it also fires between windows of the same instance (Node.xml).
   - **Development override**: when `OS.has_feature("editor")` is true and the exported flag `pause_on_focus_out_in_editor` is false (its default), FOCUS_OUT is ignored. PAUSED is never ignored. Exports always pause on FOCUS_OUT.
   - If the device run shows AppRoot does not receive these notifications, the fallback is a `MainLoop`-level hook chosen in a revision of this ADR, not a scattered handler.
5. **Fatal.** BattleBuilder receives `fatal_handler(cause: String)`, a Callable on AppRoot. It is idempotent, keeps the first cause, sets the Fatal latch and tells the battle to halt (FlowSim FATAL, `HaltState.halted()` true) in the same tick. AppRoot's next frame frees the shell and shows FatalScreen, which uses no catalogue data. A fatal during `build` discards the partial battle without ticking it.
6. **Retry and teardown.** The Retry tap only sets the latch. AppRoot checks latches in its own `_process`, which must run before the BattleWrapper's (set AppRoot `process_priority` lower than the wrapper's; Node.xml, `process_priority`). Order: Fatal first; then, if Retry is set: `shell.dispose()` (stops the wrapper with `set_process(false)`, cancels input, unregisters targets, calls `queue_free` on shell nodes), drop the only reference to the old `Battle`, build a new battle with the same stage and seed, build a new shell. The new shell nodes are new objects, so the end-of-frame free of the old ones cannot touch them.
7. **Input before ticks.** The adapter handles input in an input callback; the BattleWrapper ticks in `_process` (ADR-0003). Under the sourced flush rule, events flushed for a frame precede that frame's `_process`, so commands from that input apply before the frame's ticks. The device run in NOT SOURCEABLE confirms dispatch order.
8. **Android back button.** Out of MVP scope; `quit_on_go_back` stays at its default `true` (SceneTree.xml). Recorded so a later ADR can change it.

### Architecture Diagram

```
 engine ─▶ AppRoot (main scene, Node, process_priority lower than wrapper)
             _ready: Catalogue.load ─fail─▶ FatalScreen
                     BattleBuilder.build(cat, stage, seed, fatal_handler) ─▶ Battle (RefCounted)
                     ShellBuilder.build(battle, cat, session_flags) ─▶ Shell (nodes under AppRoot)
             _notification: APPLICATION_FOCUS_OUT | APPLICATION_PAUSED
                     ─▶ shell.adapter.cancel() ; battle.pause()   (editor override on FOCUS_OUT)
             _process: Fatal latch? ─▶ shell.dispose() ; FatalScreen
                       Retry latch? ─▶ shell.dispose() ; drop battle ; build both again
 per frame: input callback ─▶ commands on Battle ; BattleWrapper._process ─▶ ticks
```

### Key Interfaces

```gdscript
class_name AppRoot extends Node
@export var pause_on_focus_out_in_editor: bool = false
func request_retry() -> void                 # idempotent; sets the latch only
func _on_fatal(cause: String) -> void         # the injected fatal_handler; idempotent, first cause wins

class_name BattleBuilder extends RefCounted
static func build(catalogue: Catalogue, stage_id: StringName, seed: int, fatal_handler: Callable) -> Battle   # null after a fatal during build

class_name ShellBuilder extends RefCounted
static func build(battle: Battle, catalogue: Catalogue, session_flags: SessionFlags, parent: Node) -> Shell

class_name Shell extends RefCounted
var adapter: InputAdapter
func dispose() -> void                        # stop wrapper, cancel input, unregister, queue_free nodes; idempotent

class_name SessionFlags extends RefCounted
var pinned_once: bool
var built_once: bool
var won_once: bool
```

### Implementation Guidelines

- AppRoot must be the only node that handles `NOTIFICATION_APPLICATION_*`.
- The game must never set `SceneTree.paused`.
- No shell node may set `process_mode` to anything but `PROCESS_MODE_INHERIT` without a revision of this ADR.
- The Retry handler must only set the latch; teardown runs in AppRoot's `_process`.
- Fatal must be checked before Retry in the same frame.
- Shell teardown must use `queue_free`, never `free`, on nodes; sim objects are dropped, never freed.
- The teardown method is named `dispose()`, never `free()`, because `Object.free()` deletes the object (Object.xml).
- No project autoload may be added.
- Builders must only wire; no branch on a gameplay value.

## Alternatives Considered

### Alternative 1: Engine tree pause (`SceneTree.paused = true`)
- **Description**: Pause the tree; give the adapter and Paused screen `PROCESS_MODE_ALWAYS`.
- **Pros**: Stops every pausable node at once.
- **Cons**: Every input and screen node needs a mode; a missed one silently stops receiving `_input` (SceneTree.xml, `paused`). It duplicates FlowSim's Paused phase, which bots need anyway.
- **Estimated Effort**: Similar, with more surface to get wrong.
- **Rejection Reason**: Two pause mechanisms that can disagree; the sim's phase already does the job headless.

### Alternative 2: Pause on `NOTIFICATION_WM_WINDOW_FOCUS_OUT`
- **Description**: Use the window-level notification.
- **Cons**: Fires between windows of the same instance (Node.xml).
- **Rejection Reason**: Would pause on internal window changes.

### Alternative 3: Autoload app manager
- **Description**: An autoload owns the catalogue and builds battles.
- **Rejection Reason**: TR-flow-001 and TR-data-006 forbid autoloads.

### Alternative 4: Rebuild with `SceneTree.reload_current_scene`
- **Description**: Retry reloads the main scene.
- **Cons**: Loses the catalogue and session flags, which must survive Retry (TR-hud-009).
- **Rejection Reason**: Contradicts the requirement.

## Consequences

### Positive
- One pause path, shared by phone and bots.
- Lifecycle handling is in one file and easy to test by calling `_notification` directly.
- Retry is a clean rebuild with no stale state.

### Negative
- AppRoot depends on every layer by design.
- The editor override adds one flag a developer must know about.

### Neutral
- Back button behaviour stays default until a later ADR.

## Risks

- **Notifications do not reach AppRoot.** Mitigation: device run before Acceptance; fallback named in Decision 4.
- **A tick runs after `pause()` in the same frame.** Mitigation: `Battle.tick()` returns at once while Paused, and the clock resets.
- **Old shell nodes act during their last frame.** Mitigation: `dispose()` disables processing and cancels input before `queue_free`.
- **iOS gives about 5 seconds after PAUSED** (MainLoop.xml). The handler does only two calls, no I/O.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-007: no fallbacks; a bad read reaches the failure handler and the Fatal screen | Injected `fatal_handler`, Fatal latch, FatalScreen with no catalogue data |
| game-state-stage-flow.md | TR-flow-001: minimal main scene, no autoload, holds catalogue, fatal screen, retry latch, session flags | Decision 1 |
| game-state-stage-flow.md | TR-flow-002: `BattleBuilder.build(catalogue, stage_id, seed, fatal_handler)` with explicit connections, no scene | Decision 2, Key Interfaces |
| game-state-stage-flow.md | TR-flow-007: Retry rebuilds with the same seed through a latch, Fatal first | Decision 6 |
| game-state-stage-flow.md | TR-flow-008: focus loss enters Paused, clock stops, input cancels, accumulator zeroed, a tap resumes | Decisions 3 and 4 |
| game-state-stage-flow.md | TR-flow-009: idempotent handler, first cause kept, partial battle discarded, generic screen | Decision 5 |
| battle-hud.md | TR-hud-003: commands from the input call stack before the frame's ticks; Retry only sets a latch | Decisions 6 and 7 |
| battle-hud.md | TR-hud-009: prompt flags survive Retry, reset on restart | `SessionFlags` lives on AppRoot, not in the battle |
| input-gesture-resolver.md | TR-input-003 (pause part): adapter keeps receiving events while Paused | Decision 3: the tree is never paused |

## Performance Implications
- **CPU**: None per frame beyond two latch checks.
- **Memory**: One battle and one shell alive at a time, plus nodes awaiting end-of-frame free during Retry.
- **Load Time**: Catalogue loads once per app start.
- **Network**: None.

## Migration Plan

No code exists.

**Rollback plan**: Switching to tree pause is contained in AppRoot and the shell nodes' `process_mode`; supersede this ADR.

## Validation Criteria

- Unit: calling AppRoot `_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` in an export-like run moves FlowSim to PAUSED, cancels the adapter and zeroes the clock; a second call changes nothing.
- Unit: Fatal and Retry in the same frame show FatalScreen and build nothing.
- Unit: Retry keeps catalogue and session flags, gives a new `Battle`, and the old one is released (ADR-0001 test).
- Device: background and foreground the app on Android and iOS; the game is Paused and a tap resumes. Desktop export pauses on focus-out; the editor run does not, by default.
- Device: a frame log shows input commands before the frame's ticks.

## Related

- ADR-0001 (depends on), ADR-0003 (clock reset, frame hook), ADR-0006 (adapter), ADR-0005 (commands)
- `docs/architecture/architecture.md` (Module Ownership: Composition; Data Flow 1, 2 and 4; QQ-01)
- `design/gdd/game-state-stage-flow.md`, `design/gdd/battle-hud.md`, `design/gdd/data-config-pipeline.md`
