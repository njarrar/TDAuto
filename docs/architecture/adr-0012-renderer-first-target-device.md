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
>    Choice 5 (the 60 fps cap) reverses ADR-0004 Decision 11 item 14, which the
>    user confirmed on 2026-11-04; it was applied under the user's standing
>    instruction (2026-11-05) to take recommended options and stays open for the
>    user to overturn.
> 3. The platform edits to `design/gdd/game-concept.md` (cascade a1) are applied
>    or overturned by the user, because they change the concept's scope tiers.
>
> This ADR gates on no other ADR (Depends On is None). Until all three hold it
> stays `Proposed`, because the renderer, frame-cap and shader-compile
> behaviours it relies on are not in the pinned reference.
>
> **After acceptance** (phone testing set aside, user instruction 2026-11-04):
> D1 to D5 on the iPhone, with the ADR-0003 and ADR-0011 phone legs. A phone result that contradicts this
> ADR reopens it before the next story in its area closes. Reopen triggers:
> Decision 3 (Compatibility fallback), Decision 5 (cadence under the cap),
> Decision 6 (first-battle hitch), Decision 7 (Android reopens), and any engine
> upgrade (Knowledge Risk HIGH).

## Date

2026-11-05

## Last Verified

2026-11-05

## Decision Makers

User (njarrar, project owner), technical-director (TD-ADR gate), godot-specialist (engine check). Authored with the /architecture-decision flow in autonomous mode. TD-ADR returned CONCERNS (B1 to B3 blocking, A1 to A9 advisory) and the engine check returned three blocking items (E1 to E3) plus minor notes; under the user's standing instruction (2026-11-05) the recommended resolutions were taken (parent decisions P1 to P3) and every finding is applied in this revision (2026-11-05).

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

Sourced in `docs/engine-reference/godot/**`: the three renderers' one-line descriptions, Shader Baker (4.5: "pre-compiles shaders to reduce startup time"), the 4.6 D3D12 Windows default, 4.7 HDR output platforms. **NOT SOURCEABLE** there: the Mobile driver on macOS and iOS (Metal, or Vulkan through MoltenVK); whether Compatibility exports to and runs on iOS in 4.7 (it rests on OpenGL ES, which Apple has deprecated: treat the fallback as weak until D2); canvas batching (ADR-0011 V2); when canvas pipelines compile and whether a cache survives an iOS relaunch; Shader Baker for iOS presets, its key, its coverage of built-in canvas pipelines; `application/run/max_fps` (type, default), `Engine.max_fps`, a 60 cap on a 120 Hz adaptive panel; the vsync default and whether iOS honours it; the `.mobile` override, `driver.ios` and auto-fallback keys (believed `rendering/rendering_device/fallback_to_opengl3`); whether a 4.7 iOS export sets `CADisableMinimumFrameDurationOnPhone` (without it iOS is believed to hold an app at 60 Hz); the measured render-time calls; the names and iOS values of every call in Decision 4's table. "Expected" below is not a result.

**Before acceptance** (Mac; godot-specialist writes each script or prototype change, the user runs it, godot-specialist records it in `verification-results.md`):

- **R1. Run-info reads.** Windowed runs of `prototypes/adr-0011-render-budget/` and the ADR-0003 kit print one `RUNINFO` line (Decision 4) at startup, compared with the engine's Output banner; also check `RenderingServer.viewport_get_measured_render_time_cpu()` and `_gpu()` (T1's metric) return values once enabled. Expected: method `mobile`, a driver, the GPU name, a refresh rate. *Branch*: an absent or empty call is copied by hand from the banner and written `"unknown"` (so is a refresh rate of `-1.0`); the field stays mandatory.
- **R2. Project keys (headless, `prototypes/adr-checks/`).** Read `application/run/max_fps` (expected `int`, default 0), `display/window/vsync/vsync_mode` (expected enabled), `rendering/renderer/rendering_method` and any `.mobile` or `.ios` override, `rendering/rendering_device/driver.ios` (expected `metal`), every `rendering/rendering_device/fallback_to_*` key with its default, and `Engine.max_fps`. *Branch A*: no `max_fps` key: AppRoot sets `Engine.max_fps = 60` at boot. *Branch B*: an override with another value: `project.godot` sets it to `"mobile"`. *Branch C*: no fallback key: Decision 1's pin is dropped and D1 alone detects a fallback.
- **R3. Cap on the desktop.** In the spike kit's own project (not the main `project.godot`), SP14 with `max_fps=60`: ten seconds of `delta_ms` and kit ticks per frame on the Mac's display, and on any display above 60 Hz it can drive ("none available" otherwise; a 120 Hz ProMotion panel is an early E7 data point). Expected: `delta_ms` near 16.7, one tick every frame. *Branch*: uneven deltas are recorded; D3 decides on the phone.
- **R4. Renderer baseline.** ADR-0011 V2's worst case (keys 6 and 7) in the prototype, then in a copy changed only to `renderer/rendering_method="gl_compatibility"`: `RUNINFO`, draw calls (V1's method), frame cost p50 and p99, worst frame in the first five seconds after a cold start. Informational baseline for Decision 3. *Branch*: Mobile fails or draws wrongly on the Mac: escalate to `technical-director` before acceptance.
- **R5. Shader Baker in the iOS preset.** Needs the 4.7.2 iOS export templates. In a throwaway iOS preset made with ADR-0007 V7 (kept in a prototype, never committed to the main project; the blocked export-preset story makes the real one): whether the option exists, its `export_presets.cfg` key and default, whether it is offered with Mobile, and export size on and off if Xcode export works. *Branch*: no option: Decision 6 has no baker step.

**After acceptance** (iPhone; the user runs, godot-specialist records; performance-analyst owns D2 and D5):

- **D1. Renderer on the iPhone.** The first iOS debug export prints `RUNINFO` in the Xcode console. Expected: `mobile`, a Metal or Vulkan driver. *Branch*: any other method: that run is filed under the renderer reported, and this ADR reopens before the next device story closes.
- **D2. Batching and frame cost per renderer.** ADR-0011 V1 and V2 phone legs under Mobile (Low Power Mode off), plus a 10 to 15 minute sustained worst-case run, frame cost logged each minute and heat noted by hand (no thermal API); then the same under the Compatibility copy if it exports and runs, or the reason it does not. Feeds T1 and T3.
- **D3. Cadence under the cap (ADR-0004 V3).** Ten seconds of `delta_ms` and kit ticks with the cap; the reported refresh rate (it may be the panel maximum, not the adaptive rate); Low Power Mode on and off; whether the exported Info.plist has `CADisableMinimumFrameDurationOnPhone`; the sustained leg. Expected: one tick every frame. *Branch*: Decision 5.
- **D4. First-battle hitch.** Two cold launches (first after install, then a second) straight into the V2 worst case or the starter stage: every frame over 33.3 ms (two frames, to show a stall's shape; T2's 50 ms is the visible-hitch line) in the first five seconds, first with Shader Baker off (4.4 ubershaders may already hide stalls; unsourced), then on. Feeds Decision 6 and T2.
- **D5. Load time (ADR-0002 W4).** Median Loading-to-Ready over 5 cold launches against Decision 8's 1000 ms; cold launch to first frame, informational.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0011 (its V1, V2 and A1 numbers are tied to the renderer and run record fixed here; cascade a8 adds this ADR to its Depends On). ADR-0004 V3's open choice (closed by Decision 5). The Mobile Platform & Performance GDD (Vertical Slice), which inherits Decisions 4, 7 and 8 |
| **Blocks** | The iOS export preset story (with ADR-0007 V7), the first iPhone build story (MVP+), and any story whose evidence is a device run. No battle-logic or headless story waits on it |
| **Ordering Note** | Binding, not gating: ADR-0003 (display keys, spike kit), ADR-0004 (60 Hz tick, 16.6 ms split), ADR-0011 (draw-call budget, zero-shader rule), ADR-0002 (W2, W4, re-scoped by Decision 8), ADR-0010 (owns `RunInfo` and `DevLogs`, which write Decision 4's record; cascade a10). R1 to R5 need no game code and share the ADR-0003 and ADR-0011 prototype sessions on the Mac |

## Context

### Problem Statement

The 2026-11-05 architecture review (E1, E2, E7, E16; Required ADRs item 1) found no ADR choosing Mobile or Compatibility for a canvas-only game; ADR-0011's budget depends on renderer batching; a 60 Hz sim may judder on a 120 Hz iPhone; Mobile compiles canvas pipelines on first draw; and the concept, TR-data-003 and TR-data-015 still assume Android first. The user said on 2026-11-04 "I only have an iPhone for the future" and set phone testing aside.

### Current State

`project.godot` and `project.yaml` use Mobile, chosen at `/setup-engine` with no ADR. Every ADR tags phone legs "after acceptance, iPhone" and Android legs "Android-only deferred", with no decision saying what reopens Android. `game-concept.md` still says "Android debug build first". ADR-0004 item 14 leaves the fps cap to V3, a phone-only item. Game code exists (`src/root/app_root.gd`, `dev_logs.gd`, `build_info.gd`, the input adapter); no export preset exists; Run 1 (Mac, headless) recorded no renderer.

### Constraints

- Solo part-time developer; one Apple Silicon Mac and one iPhone; no Android device. iOS export needs the Mac, Xcode and signing (ADR-0007 V7).
- No CanvasItem material, shader, light, particle or 3D node in the battle (ADR-0011 Decision 7); seven `_draw` nodes on one canvas.
- 60 Hz tick in `_process`, no interpolation, a 16.6 ms split that assumes 60 fps (ADR-0004 Decisions 1, 2, 10).
- Headless runs use no renderer: only windowed or device runs can show renderer or pacing facts.

### Requirements

- One renderer named for every device result; a fallback that costs a settings change; `project.yaml` budgets (60 fps, 30 fps floor, 60 draw calls, 256 MB); TR-data-003 and TR-data-015 re-scoped to the first real device.

## Decision

### 1. Renderer: Mobile on every target at MVP

`project.godot` keeps `renderer/rendering_method="mobile"` and `config/features` "Mobile". No per-platform renderer override is set unless R2 Branch B requires one, and then only to `"mobile"`. The renderer auto-fallback key R2 finds is pinned off (`false`) at MVP, so a Mobile failure shows as a failure (T3) instead of a silent switch; it is revisited before any public release. The Mac editor, desktop runs and the iOS export all use it. Forward+ ("desktop-focused" in the reference) is not used. Why Mobile: the prototypes and ADR-0011 were written against it; the reference calls it the one optimised for mobile; the reference gives Compatibility no iOS API ("OpenGL 3.3 / WebGL 2"), so the fallback is unproven on the iPhone (D2); and the game uses no 3D, lights or post-processing, so batching and pipeline compile are the only open differences, both measured (R4, D2, D4).

### 2. Keep the fallback a settings change

Code and scenes must stay renderer-neutral, so Decision 3's switch is two lines in `project.godot` plus re-measurement:

- No HDR output and no `use_hdr_2d` (4.7 HDR output stays off on iOS and macOS).
- No `WorldEnvironment`, glow, tonemapping or `Environment` in the battle or menus.
- No `RenderingDevice`, compute shader or `DrawableTexture2D` (4.7) at MVP.
- Custom shaders stay banned in the battle (ADR-0011 Decision 7). A shader added later, anywhere, must pass a windowed run under each renderer (Mobile, then a Compatibility copy) before it merges; lint REND-4 (cascade a9) flags every new `.gdshader` or `ShaderMaterial` in `src/` or `assets/` so the run is not forgotten.
- `RenderingServer` canvas calls are allowed only as ADR-0011 V2's triangle-array branch.

### 3. Compatibility fallback and its triggers

The MVP switches to `renderer/rendering_method="gl_compatibility"` (with `config/features` updated) when the iPhone run shows any of:

- **T1. Batching or frame time.** Under Mobile, ADR-0011's V2 worst case or A1 exceeds 60 draw calls, or p99 frame cost exceeds 16.6 ms, after ADR-0011 Decision 9's levers including the triangle-array branch; and under Compatibility the same run is within both. Frame cost is CPU process time plus GPU frame time (`RenderingServer.viewport_get_measured_render_time_cpu()` and `_gpu()`, NEEDS VERIFICATION, R1), never `delta`, which reads about 16.7 ms under a 60 cap whatever the load. T1 runs record Low Power Mode off.
- **T2. Pipeline-compile stutter.** After Decision 6's steps (baker, then warm-up), the first battle after a cold launch still has a frame over 50 ms in its first five seconds that a retry does not repeat; and Compatibility does not show it.
- **T3. Renderer failure.** Mobile does not start on the iPhone, falls back on its own (D1), or draws the prototype wrongly (missing or miscoloured primitives against the Mac screenshot).

A switch needs D2 to show Compatibility runs on the iPhone; if not, T1 goes to ADR-0011's levers and content cuts, T2 and T3 to `technical-director` with the numbers. `technical-director` decides a switch on the recorded numbers and the user confirms. A switch revises this ADR, re-runs ADR-0011 V1 to V4 and A1 under the new renderer (V1's counters may differ), and re-runs D3 and D4. Shader Baker is believed to work only with Forward+ and Mobile, so after a switch Decision 6 has no baker step.

### 4. What every device run records

Each windowed, export or device run whose result any ADR uses carries a run header. A result with no header, or with a header missing a field, is **unattributed** and does not satisfy a verification item.

| Field | Source |
|---|---|
| Date, run by | by hand |
| Device | `OS.get_model_name()` as returned (on iOS an identifier such as `iPhone15,2`), plus the marketing name by hand |
| OS and version | `OS.get_name()`, `OS.get_version()` |
| Godot build | `Engine.get_version_info()` string, `OS.is_debug_build()`, editor binary or export template |
| Renderer | `RenderingServer.get_current_rendering_method()` |
| Rendering driver and GPU | `get_current_rendering_driver_name()`, `get_video_adapter_name()`, `get_video_adapter_api_version()` |
| Refresh rate | `DisplayServer.screen_get_refresh_rate()` as reported (`-1.0` is `"unknown"`), plus the panel's nominal rate by hand |
| Frame cap and vsync | `Engine.max_fps`, `DisplayServer.window_get_vsync_mode()` |
| Window and scale | window size in pixels and screen scale, as `InputAdapter` read them (ADR-0003; no new `DisplayServer` reader, lint INPUT-8) |
| Shader Baker | on, off or not offered (exports only) |
| Phone state | Low Power Mode on or off; charging or not (by hand) |

One run uses one renderer; a comparison is two runs. Results go to a "Run N" block in `verification-results.md` (its header gains these rows); evidence files in `production/qa/evidence/` start with the `RUNINFO` line. A field no source can report is `"unknown"`, never omitted. The game's debug builds write the same fields as the first record of the run log through `RunInfo`, which ADR-0010 owns (cascade a10); this ADR owns the fields, their order and the two rules above. Release builds collect nothing. Results recorded before 2026-11-05 keep counting; headless runs write `"none (headless)"` in the renderer fields.

### 5. Frame rate: a 60 fps cap on every platform (E7)

`project.godot` sets `application/run/max_fps=60` (key per R2; Branch A sets `Engine.max_fps` in AppRoot instead). Vsync stays at the engine default (R2 records it). There is no interpolation at MVP. This amends ADR-0004 Decision 11 item 14 ("No interpolation or fps cap at MVP (V3 decides)") to "no interpolation; a 60 fps cap". Why the cap and not V3 pulled forward: V3 needs the deferred phone, so it cannot move earlier; ADR-0004 Decision 10's split is written for 60 fps; a faster panel shows no new sim state, only more chances of an uneven 0/1 tick pattern; and a cap saves battery and heat. D3 confirms it on the iPhone. iOS is believed to hold an app at 60 Hz unless Info.plist sets `CADisableMinimumFrameDurationOnPhone` (engine check, unsourced): without the key the cap is redundant but harmless; with it, `max_fps` is a CPU sleep limiter that may not set the panel rate, so pacing under 120 Hz vsync can be uneven and the frame-pacing branch is the likely one on ProMotion. *Branch (D3 uneven under the cap)*: prefer display-locked 60 Hz pacing (the plist key absent, or the platform setting D3 identifies) over the sleep limiter; if that is not possible, ADR-0004 is revised to Alternative 7 (view interpolation) through TD-ADR. No sim change either way. A design request for 120 Hz motion also reopens this decision.

### 6. Shader compile: Shader Baker first, warm-up only on evidence (E16)

The iOS export preset turns Shader Baker on if R5 finds the option (the key goes into `export_presets.cfg` and lint PROJ-8, cascade a9). No hand-written warm-up exists at MVP: the battle has no custom shader, so only the engine's own canvas pipelines compile, and whether drawing them off-screen or hidden compiles them is unsourced. Shader Baker needs a Mac export host for Metal and may cover only project shaders, not the engine's canvas pipelines (engine check, unsourced), so D4 measures with it off and on. **Warm-up trigger** (D4): a frame over 50 ms in the first five seconds of the first battle after a cold launch, not repeated on retry. Then the Boot screen draws, for one frame and visibly, one of each primitive kind the battle uses (filled polygon, line, arc, `draw_multiline_colors`, `draw_texture_rect`, `draw_string` at the three sizes), and D4 is re-run. If the hitch remains, trigger T2 applies. The warm-up, if added, lives in the Boot screen only and never in the battle subtree.

### 7. Platform order: iPhone first, Android deferred

- **MVP**: desktop only (Mac, mouse as touch), as the concept's MVP tier says.
- **MVP+ (first phone build)**: an iOS debug export run on the user's iPhone. All "after acceptance, iPhone" legs of ADR-0001 to ADR-0012 run there; the Pillar 4 phone test (Input P1) runs on iPhones.
- **Android**: deferred. No Android export preset, no Android story and no Android-only setting work at MVP or MVP+. ADR text keeps Android-only legs tagged "Android-only deferred"; existing Android settings (ADR-0003 C1, `quit_on_go_back=false`) stay as decided, unverified.
- **Android reopens** at the first of: an Android device to test on; a scheduled Android release; the Vertical Slice gate, which must record a platform decision either way. Reopening means an Android preset, every "Android-only deferred" leg, Decision 3's question asked for Android (Mobile against Compatibility on an Adreno 5xx-class device, maybe as an override), and Decision 8's budgets re-measured there.

### 8. Budgets and the device class

`project.yaml` performance numbers do not change. They are measured first on the iPhone. An iPhone pass is not an Android pass: the Adreno 5xx class stays the target for Android when it reopens, and the run header (Decision 4) says which class a number came from.

- **TR-data-003**: the export load is proven on an iOS export on the iPhone (ADR-0002 W2); the Android export leg runs at Android reopen.
- **TR-data-015**: Loading to Ready, median of 5 cold launches, at most **1000 ms on the first iPhone** (D5, ADR-0002 W4), advisory at MVP+: a miss opens a load-time task, not a format change. Edit to in-game at most 10 s on the Mac (Data GDD Acceptance 14), unchanged. The Adreno 5xx-class leg runs at Android reopen.

### 9. Choices made in autonomous mode

Each is the recommended option; the user confirms or overturns each before acceptance: (1) Mobile, not Compatibility; (2) the renderer-neutral rules of Decision 2; (3) triggers T1 to T3 and their thresholds (50 ms, five seconds); (4) the run-header fields and "unattributed" rule; (5) a 60 fps cap instead of uncapped plus V3: this reverses ADR-0004 item 14, which the user confirmed on 2026-11-04 as "no fps cap, V3 decides". Confirm: ADR-0004 item 14 is rewritten (cascade a11). Overturn: Decision 5 and Alternative 3 swap, E7 returns to ADR-0004 V3, and the `max_fps` key is not added; (6) Shader Baker on, no warm-up until D4; (7) Android reopen triggers, including the Vertical Slice gate; (8) the 1000 ms load budget on the iPhone, advisory; (9) the run record contract here, with `RunInfo` owned by ADR-0010 and built with the first `DevLogs` story; (10) the auto-fallback key pinned off at MVP.

### Architecture Diagram

```
project.godot: rendering_method="mobile", run/max_fps=60
  -> Mac desktop run | iOS export (Shader Baker on)
  -> run record (RunInfo, ADR-0010; debug builds, prototypes)
  -> RUNINFO console line + run_log.jsonl first record + verification-results "Run N" header
  -> ADR-0011 V1/V2/A1, ADR-0004 V3/V6, ADR-0002 W2/W4 results
  -> T1, T2 or T3 met on the iPhone? yes: technical-director decides gl_compatibility; no: Mobile stays
```

### Key Interfaces

The run record contract (this ADR). Keys, in this order, JSON-native values (String, int, float, bool), `"unknown"` for any value no source reports: `godot`, `debug_build`, `os`, `os_version`, `model`, `method`, `driver`, `adapter`, `adapter_api`, `refresh_hz`, `max_fps`, `vsync`, `window_px`, `scale`. Console form: `RUNINFO key=value key=value ...` in the same order.

The implementation is ADR-0010's (cascade a10): `src/root/run_info.gd`, `class_name RunInfo extends RefCounted`, stateless static functions, built with the first `DevLogs` story; `window_px` and `scale` arrive as arguments read from `InputAdapter`. `DevLogs` writes `{"kind": "run_info", "launch_id", "build_hash"}` merged with the record as the first line of `run_log.jsonl` and prints the console form once. Prototypes copy the functions; they never load `src/`.

`project.godot` keys this ADR owns: `[rendering] renderer/rendering_method="mobile"` (and any override R2 Branch B adds), the auto-fallback key R2 names set to `false`; `[application] run/max_fps=60`. Export key: the Shader Baker key R5 names, in the iOS preset.

### Implementation Guidelines

- Must keep `renderer/rendering_method="mobile"`; must never add a renderer override with another value, or change the renderer, without a revision of this ADR.
- Must set `application/run/max_fps=60` (or R2 Branch A's `Engine.max_fps = 60` in AppRoot); must never raise it or set it to 0.
- Must never use HDR output, `use_hdr_2d`, `WorldEnvironment`, glow, `RenderingDevice`, compute or `DrawableTexture2D` at MVP (Decision 2).
- Must give every new shader a windowed run under each renderer before it merges (lint REND-4).
- Must start every device or windowed-run evidence file with the `RUNINFO` line; a result without the Decision 4 header must not close a verification item or story.
- Must turn Shader Baker on in the iOS preset if R5 finds it; must never add a warm-up to the battle subtree.
- Must never create an Android export preset or an Android-only story before Decision 7's reopen.
- Must write the run record only in debug builds (from `DevLogs`) and in prototypes, with every key present.
- Must keep the renderer auto-fallback key `false` at MVP.

## Alternatives Considered

### Alternative 1: Compatibility renderer for MVP
- **Description**: `gl_compatibility` everywhere now.
- **Pros**: "Broadest hardware support" (reference); may suit low-end Android later.
- **Cons**: The reference gives it no iOS API (D2 must check); all prototypes are written for Mobile; no measured reason to move.
- **Estimated Effort**: Same now; re-runs all R and D items.
- **Rejection Reason**: Unproven on the first target; kept as the triggered fallback (Decision 3).

### Alternative 2: Per-platform renderers now (Mobile on iOS, Compatibility on Android)
- **Description**: A `rendering_method.mobile` style override chosen for Android today.
- **Pros**: Matches review E1's Adreno concern.
- **Cons**: Override key unsourced; nothing can measure Android; doubles every device run.
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
- **Cons**: Unsourced effect; code with no measured need.
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
- Device numbers name their renderer, driver, device and refresh rate; the fallback stays a settings change; ADR-0004's 60 fps split holds on 120 Hz panels; one platform order with reopen triggers.

### Negative
- 120 Hz panels show 60 fps motion; a run header is extra work each device session.
- Budgets pass first on an iPhone, far from the Adreno 5xx class they were set for; low-end Android risk and Android-only behaviour (C1, density, logcat) stay hidden until Android reopens (review E1).
- With the auto-fallback pinned off, a device whose Mobile renderer fails will not start (MVP builds only reach the user's iPhone).

### Neutral
- The 4.6 D3D12 default concerns Windows only; there is no Windows target. Headless CI runs no renderer.

## Risks

- **Mobile fails or falls back on the iPhone** (D1, T3): the header and the pinned fallback key show it; Decision 3.
- **Compatibility cannot run on iOS** (D2): no renderer fallback; ADR-0011's levers, then escalation with numbers.
- **The cap paces unevenly on ProMotion** (R3, D3): Decision 5's branch; no sim change.
- **Shader Baker absent or ineffective** (R5, D4): the warm-up, then T2.
- **Android reopens late and Adreno is over budget**: the Vertical Slice gate forces a platform decision early.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| data-config-pipeline.md | TR-data-003: the catalogue loads from an explicit manifest, never a directory scan, and loads correctly from an exported build (registry text still says "an Android export"; cascade a4 rewords it) | Decisions 7 and 8: proved by ADR-0002 W2 on an iOS export, with Decision 4's header; Android leg at reopen. The manifest half stays ADR-0002 Decision 1 |
| data-config-pipeline.md | TR-data-015: Loading to Ready median at most 1000 ms on the target device; edit to in-game at most 10 s | Decision 8 sets the budget: 1000 ms median over 5 cold launches on the first iPhone, advisory, measured by D5 / ADR-0002 W4; 10 s on the Mac unchanged; the Adreno 5xx-class leg at Android reopen |
| game-concept.md | Platform: "Mobile (iOS / Android)", Technical Risks "Android debug build first", MVP+ tier "phone build (Android debug first)" (not a TR) | Decision 7 fixes iPhone first and Android deferred with reopen triggers; cascade a1 edits the concept text |
| battle-hud.md | TR-hud-015: HUD about 8 (max 12) of 60 draw calls (ADR-0011's TR; the count depends on the renderer) | Decisions 1, 3 and 4: the renderer it is counted under, the re-count on a switch, the attribution |

## Performance Implications
- **CPU**: The cap removes frames above 60 per second, so per-second view and render cost cannot double on a fast panel. The run record is collected once per launch in debug builds.
- **Memory**: None beyond the engine's renderer; Shader Baker may enlarge the export (R5 records it).
- **Load Time**: Shader Baker should shorten first-draw compile (reference: "reduce startup time"); D4 and D5 measure it.
- **Network**: None.

## Migration Plan

Game code exists, but nothing in it depends on the renderer. Before acceptance only prototypes change: the `RUNINFO` print in the two prototypes (R1), a Compatibility copy of the render-budget prototype (R4), the throwaway iOS preset (R5); R3 sets the cap in the spike kit's own project. After acceptance, in a story: `run/max_fps=60` and the fallback pin in the main `project.godot` (or R2 Branch A's AppRoot line), lint PROJ-8 and REND-4, and `RunInfo` with the first `DevLogs` story (ADR-0010).

**Rollback plan**: Renderer: Decision 3's two-line switch, or back. Cap: remove the key (returns to ADR-0004 item 14's original text). Baker: untick the preset option. None touches game code.

## Validation Criteria

1. R1 to R5 recorded on the Mac before acceptance, each with a run header.
2. Unit (ADR-0007 harness, ADR-0010's story): the console form prints every key in the fixed order, `"unknown"` for a missing value, JSON-native types only; the record has every key (values not asserted headless).
3. Lint PROJ-8 and REND-4 (cascade a9): `project.godot` has `renderer/rendering_method="mobile"`, no override with another value, the fallback key `false` and `run/max_fps=60`; once R5 names the key, the iOS preset has Shader Baker on; every new shader is flagged.
4. D1 to D5 on the iPhone after acceptance, every result with a header; D3 shows one tick per frame under the cap; none of T1 to T3 is met, or the switch is made as Decision 3 says.
5. No GDD, concept or ADR text says Android first (grep at the next `/architecture-review`).

## Related

- Amends ADR-0004 (Decision 11 item 14, V3), ADR-0002 (W2, W4 scope), ADR-0010 (Decision 10: `RunInfo` and the first record), ADR-0007 (lint PROJ-8, REND-4). Enables ADR-0011.
- `docs/architecture/architecture-review-2026-11-05.md` (E1, E2, E7, E16; Required ADRs item 1).
- `design/gdd/game-concept.md` (Platform, Technical Risks, Scope Tiers), `design/gdd/data-config-pipeline.md` (Acceptance 13, 15), `design/accessibility-requirements.md` (platform open question).
- `docs/engine-reference/godot/modules/rendering.md`, `breaking-changes.md`, `verification-results.md`.
