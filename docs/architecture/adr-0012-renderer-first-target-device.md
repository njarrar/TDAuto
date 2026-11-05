# ADR-0012: Renderer and First Target Device

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
>
> **Before acceptance** (none needs a story):
> 1. R1 to R5 below have recorded results in
>    `docs/engine-reference/godot/verification-results.md`, each run on the Mac
>    (desktop windowed run, headless script or the iOS export dialog) or in a
>    standalone prototype outside `src/`. Where a result takes a branch, this ADR
>    is revised to it first.
> 2. The user confirms or overturns each choice in Decision 9, one by one.
> 3. The platform edits to `design/gdd/game-concept.md` (cascade a1) are applied
>    or overturned by the user, because they change the concept's scope tiers.
>
> This ADR gates on no other ADR (Depends On is None). Until all three hold it
> stays `Proposed`, because the renderer, frame-cap and shader-compile
> behaviours it relies on are not in the pinned reference.
>
> Phone checks (user instruction, 2026-11-04): phone testing is set aside for
> now, and the future device is an iPhone. D1 to D5 run after acceptance, on the
> iPhone, in the same session as the ADR-0003 spike's iPhone legs and the
> ADR-0011 prototype's phone legs.
>
> **After acceptance:** D1 to D5 (iPhone). A phone result that contradicts this
> ADR reopens it before the next story in its area closes. Reopen triggers:
> Decision 3 (Compatibility fallback), Decision 5 (cadence under the cap),
> Decision 6 (first-battle hitch), Decision 7 (Android reopens), and any engine
> upgrade (Knowledge Risk HIGH).

## Date

2026-11-04

## Last Verified

2026-11-04

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate), godot-specialist (engine check). Authored with the /architecture-decision flow in autonomous mode.

## Summary

No ADR fixed the renderer for this canvas-only 2D game or the order of target platforms, so ADR-0011's draw-call numbers had no renderer to belong to and the concept still said Android first. Decided: the Mobile renderer on every target at MVP, with Compatibility as a measured fallback under three named triggers; every device run records renderer, driver, device, OS and refresh rate; a 60 fps cap on every platform; Shader Baker on in the iOS preset with a boot warm-up only if a hitch shows; and the iPhone (iOS) as the first and only phone at MVP and MVP+, with Android deferred until a named reopen trigger.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (pinned 4.7.2; `project.godot` `renderer/rendering_method="mobile"`, `config/features` "4.7", "Mobile") |
| **Domain** | Rendering (2D renderer choice, frame pacing, export) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (`architecture.md` Required ADRs row; 4.5 to 4.7 post-cutoff; the renderer's iOS behaviour is absent from the pinned reference) |
| **References Consulted** | `VERSION.md`; `modules/rendering.md` (Backend Selection; 4.5 Shader Baker; 4.6 D3D12; 4.7 HDR output, line feather, `DrawableTexture2D`, `LinearToSRGB`); `breaking-changes.md` (4.5, 4.6, 4.7 Rendering rows); `current-best-practices.md` § Rendering; `deprecated-apis.md` (nothing on renderers); `verification-results.md` Run 1. ADR-0003, ADR-0004 and ADR-0011 read by section |
| **Post-Cutoff APIs Used** | Shader Baker (4.5): an export-time option, no script API. The 4.7 HDR output feature is named only to be left off. Every script call below (`RenderingServer`, `DisplayServer`, `OS`, `Engine` reads) is pre-cutoff, and its 4.7 name and iOS value are unsourced |
| **Verification Required** | R1 to R5 before acceptance (Mac); D1 to D5 after acceptance (iPhone). Below |

> **Note**: Knowledge Risk is HIGH. This ADR must be re-validated if the project
> upgrades engine versions; flag it as "Superseded" and write a new ADR.

### Verification items

Sourced in `docs/engine-reference/godot/**`: the three renderers' one-line descriptions, Shader Baker's existence and purpose (4.5: "pre-compiles shaders to reduce startup time"), the 4.6 D3D12 default on Windows, the 4.7 HDR output platforms (iOS among them). **NOT SOURCEABLE** there: which rendering driver the Mobile renderer uses on macOS and iOS (Metal, or Vulkan through MoltenVK); whether the Compatibility renderer exports to and runs on iOS in 4.7, and on which graphics API (the reference names only OpenGL 3.3 and WebGL 2); how either renderer batches canvas commands (ADR-0011 V2 owns that); when the Mobile renderer compiles canvas pipelines and whether a pipeline cache survives an iOS relaunch; whether Shader Baker is offered for an iOS preset, under which `export_presets.cfg` key, and whether it covers the engine's built-in canvas pipelines when the project has no custom shader; the `application/run/max_fps` key and `Engine.max_fps`, and what a 60 cap does on a 120 Hz adaptive (ProMotion) panel; whether a Godot iOS app runs above 60 Hz by default; the `display/window/vsync/vsync_mode` default; the `renderer/rendering_method.mobile` override key; and the names and iOS values of `RenderingServer.get_current_rendering_method()`, `get_current_rendering_driver_name()`, `get_video_adapter_name()`, `DisplayServer.screen_get_refresh_rate()`, `DisplayServer.window_get_vsync_mode()`, `OS.get_name()`, `OS.get_version()` and `OS.get_model_name()`. "Expected" below is not a result.

**Before acceptance** (Mac; owner: godot-specialist writes each script or prototype change, the user runs it, godot-specialist records the result in `verification-results.md`):

- **R1. Run-info reads.** In a windowed run of `prototypes/adr-0011-render-budget/` and of the ADR-0003 spike kit, print one `RUNINFO` line (Decision 4's fields) at startup; compare it with the engine's own startup banner in the Output panel. Expected: method `mobile`, a driver name, the Mac's GPU name, a refresh rate in Hz. *Branch*: a call that is absent or returns empty is recorded by hand from the banner, and `RunInfo` (Key Interfaces) writes `"unknown"` for that field; the field stays mandatory in the run header.
- **R2. Project keys (headless, `prototypes/adr-checks/`).** Read `application/run/max_fps` (expected: exists, `int`, default 0), `display/window/vsync/vsync_mode` (expected: exists, default enabled), `rendering/renderer/rendering_method` and whether a `.mobile` or `.ios` override key exists; read `Engine.max_fps`. *Branch A*: `max_fps` absent: AppRoot sets `Engine.max_fps = 60` at boot instead (Decision 5). *Branch B*: an override key exists with a value other than `mobile`: `project.godot` sets it to `"mobile"` explicitly.
- **R3. Cap on the desktop.** ADR-0003 SP14 clock with `max_fps=60`: ten seconds of `delta_ms` and kit ticks per frame on the Mac's display, its refresh rate recorded; again on any display above 60 Hz the Mac can drive, if one is available (state "none available" otherwise). Expected: `delta_ms` near 16.7, one tick every frame. *Branch*: uneven deltas under the cap on a fast display are recorded; Decision 5 stands for MVP and D3 decides on the phone.
- **R4. Renderer baseline.** ADR-0011 V2's worst case (keys 6 and 7) in the prototype as is, then in a copy whose only change is `renderer/rendering_method="gl_compatibility"`. Record per run: the `RUNINFO` line, draw calls by V1's method, frame time p50 and p99, and the first-frame and first-five-seconds worst frame after a cold start. Informational: it gives Decision 3's triggers a desktop baseline and shows the fallback runs at all. *Branch*: if Mobile does not start or draws the prototype wrongly on the Mac, escalate to `technical-director` before acceptance.
- **R5. Shader Baker in the iOS preset.** In the iOS export preset made for ADR-0007 V7 (same session), record whether a Shader Baker option exists, its `export_presets.cfg` key and default, whether it is offered with the Mobile renderer, and the size of a test export with it on and off if Xcode export works then. *Branch*: no option for iOS: Decision 6 has no baker step; D4 still runs and the warm-up fallback stays the only lever.

**After acceptance** (the iPhone; owner: the user runs, godot-specialist records; performance-analyst owns D2 and D5 numbers):

- **D1. Renderer on the iPhone.** The first iOS debug export prints `RUNINFO` in the Xcode console. Expected: method `mobile`, a Metal or Vulkan driver name. *Branch*: any other method (an automatic fallback) means every result of that run is filed under the renderer actually reported, and this ADR reopens before the next device story closes.
- **D2. Batching and frame time under each renderer.** ADR-0011 V1 and V2 phone legs under Mobile; then, if the Compatibility copy of the prototype exports and runs on the iPhone, the same legs under it. Record which, with the reason if it does not run. Feeds Decision 3 triggers T1 and T3.
- **D3. Cadence under the cap (ADR-0004 V3).** Ten seconds of `delta_ms` and kit ticks on the iPhone with the cap, the reported refresh rate, Low Power Mode on and off. Expected: one tick every frame, `delta_ms` near 16.7. *Branch*: see Decision 5.
- **D4. First-battle hitch.** Two cold launches (the first after install, then a second), each straight into the prototype's V2 worst case or the real starter stage once it exists: record every frame over 33.3 ms in the first five seconds of the first battle, with Shader Baker on (and off, if R5 found the option and a re-export is quick). Feeds Decision 6 and trigger T2.
- **D5. Load time (ADR-0002 W4).** Median Loading-to-Ready over 5 cold launches on the iPhone, against Decision 8's 1000 ms; plus cold launch to first drawn frame, informational (Shader Baker changes it).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0011 (its V1, V2 and A1 numbers are tied to the renderer and run record fixed here; cascade a8 adds this ADR to its Depends On). ADR-0004 V3's open choice (closed by Decision 5). The Mobile Platform & Performance GDD (Vertical Slice), which inherits Decisions 4, 7 and 8 |
| **Blocks** | The iOS export preset story (with ADR-0007 V7), the first iPhone build story (MVP+), and any story whose evidence is a device run. No battle-logic or headless story waits on it |
| **Ordering Note** | Binding, not gating: ADR-0003 (display keys, spike kit), ADR-0004 (60 Hz tick, 16.6 ms split), ADR-0011 (draw-call budget, zero-shader rule), ADR-0002 (W2, W4, re-scoped by Decision 8), ADR-0010 (`DevLogs` writes Decision 4's record). R1 to R5 need no game code and share the ADR-0003 and ADR-0011 prototype sessions on the Mac |

## Context

### Problem Statement

The 2026-11-05 architecture review (E1, E2, E7, E16; Required ADRs item 1) found no ADR choosing Mobile or Compatibility for a canvas-only game; ADR-0011's budget depends on renderer batching; a 60 Hz sim may judder on a 120 Hz iPhone; Mobile compiles canvas pipelines on first draw; and the concept, TR-data-003 and TR-data-015 still assume Android first. The user said on 2026-11-04 "I only have an iPhone for the future" and set phone testing aside. Device results are about to be recorded by several ADRs; each needs to say which renderer produced it.

### Current State

`project.godot` and `project.yaml` use Mobile, chosen at `/setup-engine` with no ADR. Every ADR tags phone legs "after acceptance, iPhone" and Android legs "Android-only deferred", with no decision saying what reopens Android. `game-concept.md` still says "Android debug build first". ADR-0004 item 14 leaves the fps cap to V3, a phone-only item. No export preset exists; Run 1 (Mac, headless) recorded no renderer.

### Constraints

- Solo part-time developer; one Mac (Apple Silicon, `verification-results.md` Run 1) and one iPhone; no Android device. iOS export needs the Mac, Xcode and signing (`game-concept.md` Engine row; ADR-0007 V7).
- The battle uses no CanvasItem material, shader, `Light2D`, particle or 3D node (ADR-0011 Decision 7; registry `canvas_shader_or_particles_in_battle`). Seven `_draw` nodes on one canvas (ADR-0011 Decision 1).
- 60 Hz fixed tick in `_process`, no interpolation, a 16.6 ms frame split that assumes 60 fps (ADR-0004 Decisions 1, 2, 10).
- Headless test runs use no renderer, so no automated test can check the renderer or frame pacing; evidence is a windowed or device run (ADR-0007).
- No engine behaviour is taken from training data; unsourced items become verification items.

### Requirements

- One renderer named for every device result; a fallback that costs a settings change; `project.yaml` budgets (60 fps, 30 fps floor, 60 draw calls, 256 MB); TR-data-003 and TR-data-015 re-scoped to the first real device.

## Decision

### 1. Renderer: Mobile on every target at MVP

`project.godot` keeps `renderer/rendering_method="mobile"` and `config/features` "Mobile". No per-platform renderer override is set unless R2 Branch B requires one, and then only to `"mobile"`. The Mac editor, desktop runs and the iOS export all use it. Forward+ ("desktop-focused" in the reference) is not used. Why Mobile: it is the configured renderer the prototypes and ADR-0011 were written against; the reference describes it as the one optimised for mobile; on iOS the reference gives Compatibility no API at all ("OpenGL 3.3 / WebGL 2"), so the fallback's availability on the iPhone is itself unproven (D2); and the game uses none of the features where the renderers differ most (3D, lights, post-processing), so batching and pipeline compile are the only open differences, and both are measured (R4, D2, D4).

### 2. Keep the fallback a settings change

Code and scenes must stay renderer-neutral, so Decision 3's switch is two lines in `project.godot` plus re-measurement:

- No HDR output and no `use_hdr_2d` (4.7 HDR output stays off on iOS and macOS).
- No `WorldEnvironment`, glow, tonemapping or `Environment` in the battle or menus.
- No `RenderingDevice`, compute shader or `DrawableTexture2D` (4.7) at MVP.
- Custom shaders stay banned in the battle (ADR-0011 Decision 7). A shader added later, anywhere, must compile under both renderers before it merges.
- `RenderingServer` canvas calls are allowed only as ADR-0011 V2's triangle-array branch.

### 3. Compatibility fallback and its triggers

The MVP switches to `renderer/rendering_method="gl_compatibility"` (with `config/features` updated) when the iPhone run shows any of:

- **T1. Batching or frame time.** Under Mobile, ADR-0011's V2 worst case or A1 exceeds 60 draw calls, or p99 frame time exceeds 16.6 ms, after ADR-0011 Decision 9's levers including the triangle-array branch; and under Compatibility the same run is within both.
- **T2. Pipeline-compile stutter.** After Decision 6's steps (baker, then warm-up), the first battle after a cold launch still has a frame over 50 ms in its first five seconds that a retry does not repeat; and Compatibility does not show it.
- **T3. Renderer failure.** Mobile does not start on the iPhone, falls back on its own (D1), or draws the prototype wrongly (missing or miscoloured primitives against the Mac screenshot).

A switch needs D2 to show Compatibility runs on the iPhone. If it does not, there is no fallback: T1 goes to ADR-0011's levers and content cuts, T2 and T3 go to `technical-director` with the measurements. The decision to switch is `technical-director`'s on the recorded numbers, confirmed by the user. A switch revises this ADR (Status note and Decision 1), re-runs ADR-0011 V1 to V4 and A1 under the new renderer (V1's counters may differ), and re-runs D3 and D4.

### 4. What every device run records

Each windowed, export or device run whose result any ADR uses carries a run header. A result with no header, or with a header missing a field, is **unattributed** and does not satisfy a verification item.

| Field | Source |
|---|---|
| Date, run by | by hand |
| Device | model and model identifier (`OS.get_model_name()`, R1), e.g. the iPhone's model name |
| OS and version | `OS.get_name()`, `OS.get_version()` |
| Godot build | engine version string, debug or release, editor binary or export template |
| Renderer | `RenderingServer.get_current_rendering_method()` |
| Rendering driver and GPU | `get_current_rendering_driver_name()`, `get_video_adapter_name()` |
| Refresh rate | `DisplayServer.screen_get_refresh_rate()` as reported, plus the panel's nominal rate by hand |
| Frame cap and vsync | `Engine.max_fps`, `DisplayServer.window_get_vsync_mode()` |
| Window and scale | window size in pixels, `screen_get_scale()` (ADR-0003 SP9) |
| Shader Baker | on, off or not offered (exports only) |
| Phone state | Low Power Mode on or off; charging or not (by hand) |

One run uses one renderer; a comparison is two runs with two headers. Results go to a new "Run N" block in `docs/engine-reference/godot/verification-results.md` (its header table gains these rows) and evidence files in `production/qa/evidence/` start with the `RUNINFO` line. The game's debug builds write the same fields as the first record of the run log (ADR-0010 Decision 10, cascade a10). Release builds collect nothing.

### 5. Frame rate: a 60 fps cap on every platform (E7)

`project.godot` sets `application/run/max_fps=60` (key per R2; Branch A sets `Engine.max_fps` in AppRoot instead). Vsync stays at the engine default (R2 records it). There is no interpolation at MVP. This amends ADR-0004 Decision 11 item 14 ("No interpolation or fps cap at MVP (V3 decides)") to "no interpolation; a 60 fps cap". Why the cap and not pulling V3 forward: V3 can only run on the phone, and phone testing is deferred, so "forward" would still mean "after acceptance"; ADR-0004 Decision 10's frame split is written for 60 fps; with a 60 Hz sim and no interpolation a faster panel shows no new state, only more chances of an uneven 0/1 tick pattern on an adaptive panel; and a cap also saves battery and heat on a game played in short sessions. D3 confirms it on the iPhone. *Branch (D3 uneven under the cap)*: ADR-0004 is revised to Alternative 7 (view interpolation) or to a platform frame-pacing setting the run identifies, through TD-ADR; no sim change either way. A design request for 120 Hz motion also reopens this decision.

### 6. Shader compile: Shader Baker first, warm-up only on evidence (E16)

The iOS export preset turns Shader Baker on if R5 finds the option (the key goes into `export_presets.cfg` and lint PROJ-8, cascade a9). No hand-written warm-up exists at MVP: the battle has no custom shader, so only the engine's own canvas pipelines compile, and whether drawing them off-screen or hidden compiles them is unsourced. **Warm-up trigger** (D4): a frame over 50 ms in the first five seconds of the first battle after a cold launch, not repeated on retry. Then the Boot screen draws, for one frame and visibly, one of each primitive kind the battle uses (filled polygon, line, arc, `draw_multiline_colors`, `draw_texture_rect`, `draw_string` at the three sizes), and D4 is re-run. If the hitch remains, trigger T2 applies. The warm-up, if added, lives in the Boot screen only and never in the battle subtree.

### 7. Platform order: iPhone first, Android deferred

- **MVP**: desktop only (Mac, mouse as touch), as the concept's MVP tier says.
- **MVP+ (first phone build)**: an iOS debug export run on the user's iPhone. All "after acceptance, iPhone" legs of ADR-0001 to ADR-0012 run there; the Pillar 4 phone test (Input P1) runs on iPhones.
- **Android**: deferred. No Android export preset, no Android story and no Android-only setting work at MVP or MVP+. ADR text keeps Android-only legs tagged "Android-only deferred"; existing Android settings (ADR-0003 C1, `quit_on_go_back=false`) stay as decided, unverified.
- **Android reopens** when the first of these happens: the user has an Android device to test on; the producer schedules an Android release; or the Vertical Slice gate, which must record a platform decision either way. Reopening means: an Android preset; every "Android-only deferred" leg in `verification-results.md` "Still open"; Decision 3's question asked again for Android (Mobile against Compatibility on an Adreno 5xx-class device, possibly as a per-platform override); and Decision 8's budgets re-measured on that device.

### 8. Budgets and the device class

`project.yaml` performance numbers do not change. They are measured first on the iPhone. An iPhone pass is not an Android pass: the Adreno 5xx class stays the target for Android when it reopens, and the run header (Decision 4) says which class a number came from.

- **TR-data-003**: the export load is proven on an iOS export on the iPhone (ADR-0002 W2); the Android export leg runs at Android reopen.
- **TR-data-015**: Loading to Ready, median of 5 cold launches, at most **1000 ms on the first iPhone** (D5, ADR-0002 W4), advisory at MVP+: a miss opens a load-time task, not a format change. Edit to in-game at most 10 s on the Mac (Data GDD Acceptance 14), unchanged. The Adreno 5xx-class leg runs at Android reopen.

### 9. Choices made in autonomous mode

Each is the recommended option; the user confirms or overturns each before acceptance: (1) Mobile, not Compatibility; (2) the renderer-neutral rules of Decision 2; (3) triggers T1 to T3 and their thresholds (50 ms, five seconds); (4) the run-header fields and "unattributed" rule; (5) a 60 fps cap instead of uncapped plus V3; (6) Shader Baker on, no warm-up until D4; (7) Android reopen triggers, including the Vertical Slice gate; (8) the 1000 ms load budget on the iPhone, advisory; (9) `RunInfo` in `src/root/` and its first-record line in the run log.

### Architecture Diagram

```
project.godot: rendering_method="mobile", run/max_fps=60
  -> Mac desktop run | iOS export (Shader Baker on)
  -> RunInfo.collect() (debug builds, prototypes)
  -> RUNINFO console line + run_log.jsonl first record + verification-results "Run N" header
  -> ADR-0011 V1/V2/A1, ADR-0004 V3/V6, ADR-0002 W2/W4 results
  -> T1, T2 or T3 met on the iPhone? yes: technical-director decides gl_compatibility; no: Mobile stays
```

### Key Interfaces

```gdscript
# src/root/run_info.gd  (debug builds and prototypes only; no state)
class_name RunInfo
extends RefCounted

## Reads the engine, renderer and display facts of Decision 4 once.
## JSON-native values only (String, int, float). A field the engine cannot
## report is "unknown" (R1). Never called in release builds.
static func collect() -> Dictionary

## Formats collect()'s dictionary as one console line:
## "RUNINFO key=value key=value ..." in a fixed key order. Pure; unit-tested.
static func line(info: Dictionary) -> String
```

Keys, in order: `godot`, `build` (`debug` or `release`), `os`, `os_version`, `model`, `method`, `driver`, `adapter`, `refresh_hz`, `max_fps`, `vsync`, `window_px`, `scale`. `DevLogs` (ADR-0010 Decision 10) writes `{"kind": "run_info", "launch_id": ..., "build_hash": ...}` merged with `collect()` as the run log's first record at boot, and prints `line()` once. Prototypes copy these two functions; they never load `src/`.

`project.godot` keys this ADR owns: `[rendering] renderer/rendering_method="mobile"` (and any override R2 Branch B adds); `[application] run/max_fps=60`. Export key: the Shader Baker key R5 names, in the iOS preset.

### Implementation Guidelines

- Must keep `renderer/rendering_method="mobile"`; must never add a renderer override with another value, or change the renderer, without a revision of this ADR.
- Must set `application/run/max_fps=60` (or R2 Branch A's `Engine.max_fps = 60` in AppRoot); must never raise it or set it to 0.
- Must never use HDR output, `use_hdr_2d`, `WorldEnvironment`, glow, `RenderingDevice`, compute or `DrawableTexture2D` at MVP (Decision 2).
- Must start every device or windowed-run evidence file with the `RUNINFO` line; a result without the Decision 4 header must not close a verification item or story.
- Must turn Shader Baker on in the iOS preset if R5 finds it; must never add a warm-up to the battle subtree.
- Must never create an Android export preset or an Android-only story before Decision 7's reopen.
- Must call `RunInfo.collect()` only in debug builds (from `DevLogs`) and in prototypes.

## Alternatives Considered

### Alternative 1: Compatibility renderer for MVP
- **Description**: `gl_compatibility` everywhere now.
- **Pros**: "Broadest hardware support" (reference); may suit low-end Android later.
- **Cons**: The reference gives it no iOS API (D2 must check); all prototypes are written for Mobile; no measured reason to move.
- **Estimated Effort**: Same now; re-runs all R and D items.
- **Rejection Reason**: Unproven on the first target; kept as the triggered fallback (Decision 3).

### Alternative 2: Per-platform renderers now (Mobile on iOS, Compatibility on Android)
- **Description**: A `rendering_method.mobile` style override chosen for Android today.
- **Pros**: Matches review finding E1's Adreno concern.
- **Cons**: The override key is unsourced; nothing can measure Android; two renderers double every device run.
- **Estimated Effort**: Higher.
- **Rejection Reason**: Premature; it is the first question Android's reopen asks (Decision 7).

### Alternative 3: Uncapped frame rate, pull ADR-0004 V3 forward, interpolate if needed
- **Description**: Keep ADR-0004 item 14; run V3 early and add interpolation (ADR-0004 Alternative 7) if 120 Hz judders.
- **Pros**: Could use 120 Hz panels fully.
- **Cons**: V3 needs the deferred phone, so nothing moves forward; interpolation draws positions the sim never had; per-second view cost doubles at 120 Hz.
- **Estimated Effort**: Higher (interpolation in every model).
- **Rejection Reason**: Cannot be done earlier and buys no gameplay; the cap is one key (Decision 5).

### Alternative 4: Hand-written pipeline warm-up instead of Shader Baker
- **Description**: A Boot-screen frame drawing every primitive kind, always.
- **Pros**: Independent of export options.
- **Cons**: Whether it compiles the right pipelines is unsourced; code with no measured need.
- **Estimated Effort**: Low, plus a test it works.
- **Rejection Reason**: Kept as the evidence-triggered second step (Decision 6).

### Alternative 5: Android first
- **Description**: The concept's original order: Android debug build first, iOS at Vertical Slice.
- **Pros**: Cheaper signing; the low-end budget class is Android.
- **Cons**: The user has no Android device.
- **Estimated Effort**: Not possible now.
- **Rejection Reason**: User instruction, 2026-11-04.

## Consequences

### Positive
- Every device number names its renderer, driver, device and refresh rate, so results compare across runs; the fallback stays a two-line change; ADR-0004's 60 fps split holds on 120 Hz panels; concept, GDDs and ADRs agree on one platform order with reopen triggers.

### Negative
- 120 Hz panels show 60 fps motion.
- Budgets pass first on an iPhone, which is far from the Adreno 5xx class they were set for; low-end Android risk stays hidden until Android reopens (review E1).
- A run header on every evidence file is extra work for each device session.
- Android-only behaviour (back gesture C1, density, logcat) stays unverified for a long time.

### Neutral
- The 4.6 D3D12 default concerns Windows only; there is no Windows target. Headless CI runs no renderer.

## Risks

- **Mobile fails or falls back on the iPhone** (D1, T3). Mitigation: the run header shows it at once; Decision 3.
- **Compatibility cannot run on iOS** (D2), leaving no renderer fallback. Mitigation: ADR-0011's levers and the triangle-array branch; escalation with numbers.
- **The cap paces unevenly on ProMotion** (R3, D3). Mitigation: Decision 5's branch; no sim change.
- **Shader Baker absent for iOS or ineffective for canvas pipelines** (R5, D4). Mitigation: the warm-up step, then T2.
- **Android reopens late and finds Adreno over budget.** Mitigation: the Vertical Slice gate trigger forces a platform decision before content scales.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-003: the catalogue loads from an explicit manifest, never a directory scan, and loads correctly from an exported build (registry text still says "an Android export"; cascade a4 rewords it) | Decision 7 (iPhone is the first export target), Decision 8 (proved by ADR-0002 W2 on an iOS export; Android leg at reopen), Decision 4 (W2's run carries the header). The manifest half stays ADR-0002 Decision 1 |
| data-config-pipeline.md | TR-data-015: Loading to Ready median at most 1000 ms on the target device; edit to in-game at most 10 s | Decision 8 sets the budget: 1000 ms median over 5 cold launches on the first iPhone, advisory, measured by D5 / ADR-0002 W4; 10 s on the Mac unchanged; the Adreno 5xx-class leg at Android reopen |
| game-concept.md | Platform: "Mobile (iOS / Android)", Technical Risks "Android debug build first", MVP+ tier "phone build (Android debug first)" (not a TR) | Decision 7 fixes iPhone first and Android deferred with reopen triggers; cascade a1 edits the concept text |
| battle-hud.md | TR-hud-015: HUD about 8 (max 12) of 60 draw calls (ADR-0011's TR; listed here because the count depends on the renderer) | Decision 1 fixes the renderer the count is taken under; Decision 3 names the re-count on a switch; Decision 4 attributes each count |

## Performance Implications
- **CPU**: The cap removes frames above 60 per second, so per-second view and render cost cannot double on a fast panel. `RunInfo.collect()` runs once per launch in debug builds.
- **Memory**: None beyond the engine's renderer; Shader Baker may enlarge the export (R5 records it).
- **Load Time**: Shader Baker is expected to shorten first-draw compile (reference: "reduce startup time"); D4 and D5 measure it. The 1000 ms catalogue budget is Decision 8's.
- **Network**: None.

## Migration Plan

No game code exists. `run/max_fps=60` goes into `project.godot` after R2; the `RUNINFO` print into the two prototypes (R1); a Compatibility copy of the prototype for R4; Shader Baker into the iOS preset at ADR-0007 V7; `RunInfo` with the first `DevLogs` story.

**Rollback plan**: Renderer: Decision 3's two-line switch, or back. Cap: remove the key (returns to ADR-0004 item 14's original text). Baker: untick the preset option. None touches game code.

## Validation Criteria

1. R1 to R5 recorded on the Mac before acceptance, each with a run header.
2. Unit (ADR-0007 harness): `RunInfo.line()` prints every key in the fixed order, `"unknown"` for a missing value, JSON-native types only; `collect()` returns every key (values not asserted headless).
3. Lint PROJ-8 (cascade a9): `project.godot` has `renderer/rendering_method="mobile"`, no override with another value, and `run/max_fps=60`; once R5 names the key, the iOS preset has Shader Baker on.
4. D1 to D5 on the iPhone after acceptance, every result with a header; D3 shows one tick per frame under the cap; none of T1 to T3 is met, or the switch is made as Decision 3 says.
5. No GDD, concept or ADR text says Android first (grep at the next `/architecture-review`).

## Related

- Amends ADR-0004 (Decision 11 item 14, V3), ADR-0002 (W2, W4 scope), ADR-0010 (Decision 10 first record), ADR-0007 (lint PROJ-8). Enables ADR-0011.
- `docs/architecture/architecture-review-2026-11-05.md` (E1, E2, E7, E16; Required ADRs item 1).
- `design/gdd/game-concept.md` (Platform, Technical Risks, Scope Tiers), `design/gdd/data-config-pipeline.md` (Acceptance 13, 15), `design/accessibility-requirements.md` (platform open question).
- `docs/engine-reference/godot/modules/rendering.md`, `breaking-changes.md`, `verification-results.md`.
