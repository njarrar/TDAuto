# ADR-0007 Companion: Lint Rule Catalogue

Part of `docs/architecture/adr-0007-headless-test-harness-gdunit4-layer-lint.md` (Proposed).
This file changes only through that ADR's review (technical-director, with the user's
confirmation), like an amendment. `tools/lint/lint_rules.gd` mirrors it: the
integration lint test fails when the rule IDs in `lint_rules.gd` and the IDs in the tables
below differ. A rule whose owning ADR is not Accepted is marked **pending** and is switched
off in `lint_rules.gd` until that ADR is Accepted; a pending rule prints
`pending: <RULE> (<ADR>)` on every run, so it is never silent.

Last updated: 2026-11-05 (PHYS-1 added after /architecture-review, TR-state-003). Before: 2026-11-04 (INIT-1 added from ADR-0009 V7 result).

## 1. How the lint reads code

- **Masking.** Before matching, comments (`#`, `##`) and string contents are masked, line
  numbers kept. String forms: `"..."`, `'...'`, `"""..."""`, `'''...'''`, `&"..."`
  (StringName), `^"..."` (NodePath), `r"..."` (raw), plus `$"..."` and `%"..."` node shorthands.
  Escapes (`\"`, `\\`) are honoured; a `#` inside a triple-quoted string is not a comment.
- **Logical lines.** A statement continued inside open brackets or after `\` is joined.
- **Bodies.** A function body is every following line indented deeper than its `func` line;
  a multi-line lambda's body (only legal under `tests/`) is indented the same way.
- **Paths.** Path rules read the unmasked string of `preload(`, `load(` and, in `.tscn` files,
  the `path=` attribute of `[ext_resource ...]` (never `uid=`).
- **Regex.** `RegEx.create_from_string(pattern, true)` (`show_error`, 4.4, `breaking-changes.md`);
  global-function rules use the fixed-length lookbehind `(?<![\w.])` (V6).
- **Findings** print as `<res path>:<line>: <RULE> <message>`.
- **Coverage output.** For every rule the run prints the number of in-scope files it checked.
  A rule aimed at a named file or a named class whose file is absent prints
  `not assessed: <RULE> <file> absent` (like PROJ-6 and PROJ-7), never nothing.
- **Exceptions** live only in `FILE_EXCEPTIONS` in `lint_rules.gd` (rule, file, the ADR
  decision allowing it). No inline suppression. Budget: ten rows by the end of MVP, or ADR-0007
  is reopened.

## 2. Scopes and sets

| Name | Content | Derived or kept, and why |
|---|---|---|
| Layer map | `src/foundation/` 0, `src/core/` 1, `src/feature/` 2, `src/presentation/` 3, `src/root/` 4 | Kept: `architecture.md` layer map |
| Class index | Every `class_name X` under `src/`, `tests/`, `tools/`, `addons/` with its file and layer | Derived (repo scan) |
| Engine names | `ClassDB.class_exists(X)`, plus a static list of Variant type names (`bool`, `int`, `float`, `String`, `StringName`, `NodePath`, `Vector2` to `Vector4i`, `Rect2`, `Rect2i`, `Transform2D`, `Transform3D`, `Plane`, `Quaternion`, `AABB`, `Basis`, `Projection`, `Color`, `RID`, `Object`, `Callable`, `Signal`, `Dictionary`, `Array`, every `Packed*Array`) and `@GlobalScope` | Derived from the engine, plus a kept list: `ClassDB` does not report Variant types (engine check) |
| Battle signals | Signal names in the keys of `tests/integration/battle_wiring/battle_signal_contract.gd` (`WIRING`, `VIEW_ALLOWLIST`) | Derived; ADR-0006's headless test proves the contract complete |
| Battle emitter files | The files declaring `Flow`, `Combat`, `EnemyWave`, `TowerSim`, `HeroSim`, `InputResolver` (the classes behind `Battle.EMITTER_KEYS`), plus `InputAdapter` | Kept map key to class (the keys are not class names); ADR-0006 owns the keys |
| Enums | Every `enum X` declared under `src/`, by class | Derived |
| Sim scope | `src/core/**`, `src/feature/**`, `src/foundation/data/**`, `sim_time.gd`, `sim_rng.gd`, `fatal_latch.gd` in `src/foundation/`, and `battle.gd`, `fatal_relay.gd`, `battle_builder.gd` in `src/root/` | Kept: no mechanical test tells a sim class from a view (ADR-0004 Decision 9 defines it in words) |
| Real-time models | Files of `HudLogic`, `TowerInput`, `ChipWindow`, `HeroInput` | Kept class list (ADR-0004 Decision 8); files found through the class index |
| Battle scope | Every file under `src/` except `src/root/app_root.gd`, `src/root/fatal_screen.tscn` and folders in `NON_BATTLE` (empty at MVP; the Vertical Slice Menu and Settings stories add theirs) | Kept: "battle code" is the owning ADRs' term, not a folder |
| Commands | `pin`, `burst`, `build`, `upgrade`, `start_wave`, `call_early`, `pause`, `resume` | Kept: registry `command_inside_tick` (ADR-0004); ADR-0010 extends it |
| Gesture signals that may command | `pressed`, `tapped`, `ground_tapped`, `drag_started`, `drag_moved`, `drag_ended` (G1 to G6) | Kept: ADR-0006 Decision 7 rule 3 |
| Project keys | The rows of PROJ-2 to PROJ-5 | Kept: copied from ADR-0001, ADR-0003, ADR-0004 and this ADR |

Whoever changes an ADR that a kept row cites changes that row, and `lint_rules.gd`, in the same change.

## 3. Rules

Scope is all of `src/` unless stated. "C-n" marks a rule stricter than its owning ADR, held as
ADR-0007 Decision 13 item C-n; if the user overturns C-n, the rule takes the owner's scope given
in brackets.

### Layer and names

| ID | Fails when | Source |
|---|---|---|
| LAYER-1 | A file references a `class_name` or a `res://src/<layer>/` path of a higher layer. `root` may reference all layers; nothing outside `root` references `root`. `extends`, type hints, `Class.CONST`, `Class.Enum` and `.tscn` `path=` all count | `architecture.md` rules 1 to 3, 5 |
| LAYER-2 | A file in `src/feature/<m>/` references a class or path in `src/feature/<n>/`, m not n | rule 4 |
| LAYER-3 | A `.gd` or `.tscn` under `src/` is outside the five layer folders | rule 6 |
| LAYER-4 | `src/` references a class declared under, or a path into, `addons/`, `tests/`, `tools/` or `prototypes/` | rule 2; ADR-0007 Decision 1 |
| LAYER-5 | `uid://` appears in a `.gd` under `src/` (it would bypass LAYER-1 and LAYER-4; engine check E2) | ADR-0007 |
| NAME-1 | Two scripts under `src/`, `tests/`, `tools/`, `addons/` declare the same `class_name` | QQ-16 |
| NAME-2 | A `src/` `class_name` is an engine name (Section 2) | QQ-16 |
| NAME-3 | A script under `tests/` or `tools/` declares `class_name` (also catches gdUnit4's "create test" template, which adds one) | ADR-0007 Decision 1 |
| NAME-4 | A `src/` `class_name` is not the PascalCase of its file name | `project.yaml` naming |
| NAME-5 | A function, parameter or variable in `src/` is named `load` or `seed` | ADR-0002 `method_named_load`; ADR-0001 rename (QQ-15) |

### Wiring and signals

| ID | Fails when | Source |
|---|---|---|
| WIRE-1 | `Callable(` is called with any argument (the string form `Callable(obj, "name")`); the empty `Callable()` is legal | ADR-0001 Decision 5 |
| WIRE-2 | `connect(`, `disconnect(`, `is_connected(` or `emit_signal(` takes a string or StringName literal first, or `emit_signal(` appears | ADR-0001, ADR-0006 Decision 1 |
| WIRE-3 | A lambda appears (`func` then `(` with no name) | C2 [owner: a lambda inside a `.connect(` argument, or anywhere in `battle_builder.gd` or `battle_wrapper.gd`] |
| WIRE-4 | `.bind(` or `.unbind(` appears inside a `.connect(` argument, or anywhere in `battle_builder.gd` or `battle_wrapper.gd` (the only places that inject or connect, ADR-0001 and ADR-0006) | ADR-0001 |
| WIRE-5 | A `CONNECT_` constant appears in a `.connect(` of a battle signal, or anywhere in `battle_builder.gd` or `battle_wrapper.gd` | ADR-0006 Decision 2 (**pending ADR-0006**) |
| WIRE-6 | `.<s>.connect(` or `.<s>.disconnect(` for a battle signal `s` outside `battle_builder.gd` and `battle_wrapper.gd` | ADR-0006 Decision 2 (**pending**) |
| WIRE-7 | A `.tscn` under `src/` has `[connection signal="<s>"` for a battle signal `s` | ADR-0006 Decision 2; token V6 (**pending**) |
| WIRE-8 | A battle-signal connection `x.s.connect(y.m)` has `m` other than `on_s` or `_on_s` | C3 [owner: no rule; WIRE-9 becomes code review] (**pending**) |
| WIRE-9 | The body of `on_s` or `_on_s`, for a battle signal `s`: calls `.tick(`, `.deliver(`, `.apply_slow(` or a command, unless `s` may command (Section 2); in `src/presentation/` or `battle_wrapper.gd` also calls `.emit(`, `.connect(`, `.disconnect(` or `request_retry(`; for `attack_fired` and `damage_applied` also calls `stat_int(` or `stat_float(` | ADR-0004 `command_inside_tick`; ADR-0006 Decision 7 rules 1 to 4 (**pending**) |
| WIRE-10 | In a battle emitter file, a `signal` parameter is untyped or typed other than `int`, `float`, `bool`, `StringName`, `Vector2` or a `src/` enum | ADR-0006 Decision 4 (**pending**) |
| WIRE-11 | `signal` is declared under `src/foundation/data/` | ADR-0002, ADR-0006 Validation 6 (**pending**) |
| WIRE-12 | In a battle emitter file or the sim scope, a parameter or variable named `id` or `*_id` is typed `String` | ADR-0006 Decision 4 (**pending**) |

### State and ownership

| ID | Fails when | Source |
|---|---|---|
| STATE-1 | `static var` appears | ADR-0001 `mutable_static_var` |
| STATE-2 | In the sim scope, a member is typed `Battle` | ADR-0001 `sim_back_reference_to_battle` |
| STATE-3 | `func reset(` in the sim scope (`drop_backlog` is not matched) | ADR-0001 `in_place_reset` |
| STATE-4 | `.hp`, `.max_hp`, `.strength` or `.ticks_left` is assigned (`=`, `+=`, `-=`, `*=`, `/=`) outside `src/core/combat/` (records under `src/foundation/data/records/` build their own authored `max_hp` from data, ADR-0002) | ADR-0009 `hp_change_outside_deliver` |
| STATE-5 | `.add_enemy(` outside `src/feature/enemy_wave/` | ADR-0009 Decision 7 |
| STATE-6 | `roster()`, `targets()` or `targets.call()` is followed directly by a mutating call (`append`, `erase`, `sort`, `sort_custom`, `clear`, `remove_at`, `insert`, `push_*`, `pop_*`, `resize`, `fill`, `reverse`, `shuffle`, `assign`) | ADR-0009 `mutate_roster_view` (partial) |
| STATE-7 | In the files of `Targetable`, `Enemy`, `Health`, `Status`, `PathTrack`, a member is typed `ReadContext`, `EnemyWave`, `Combat`, `Battle`, `Callable`, `Targetable`, `Enemy`, `Object`, `Node` or `RefCounted` (`Health` and `Status` members typed on `Targetable`'s own fields are the owner's) | ADR-0009 `combat_piece_back_reference`; ADR-0005 `entity_holds_own_read_context` |
| STATE-8 | Inside `for x in a:`, the body calls `a.erase(`, `a.remove_at(`, `a.pop_*(` or `a.clear(` | ADR-0009 `remove_during_foreach` |
| STATE-9 | In one file, a member with a setter typed `Packed*Array` has an element written (`name[i] =`) | ADR-0007 Decision 11 (QQ-15) |
| STATE-10 | `catalogue.gd` or a file under `src/foundation/data/records/` declares a `Callable` member | ADR-0002 Implementation Guidelines |
| STAT-1 | The second argument of `stat_int(` or `stat_float(` does not start with `StatKeys.` | ADR-0005 `stat_key_literal` |

### Time, maths and randomness

| ID | Fails when | Source |
|---|---|---|
| TIME-1 | `_physics_process` is declared | ADR-0004 |
| TIME-2 | `_process` is declared outside `battle_wrapper.gd`, `app_root.gd`, `input_adapter.gd` | ADR-0004 |
| TIME-3 | `Timer`, `create_timer(`, `await`, `Engine.time_scale`, `Engine.get_frames_drawn`, `Engine.get_process_frames`, `Engine.get_physics_frames`, `Time.` or `OS.get_ticks_` appears. File exceptions: `Time.get_unix_time_from_system` and `Time.get_ticks_msec` in `app_root.gd` (seed, ADR-0004 V8); `Time.get_ticks_usec` in `battle_wrapper.gd` (dev timers); `Time.` under `src/presentation/dev/` (ADR-0008 `GestureLog`, **verify against final ADR-0008**). Excluded from the rule: `src/root/dev_logs.gd` (`Time.get_unix_time_from_system` for the launch id, ADR-0010) and `src/presentation/dev/gesture_log.gd` (ADR-0008) | C4 [owner: sim scope and real-time models only] |
| TIME-4 | `get_tree().paused` or `low_processor_mode` appears | ADR-0003 `scene_tree_pause`; ADR-0004 |
| TIME-5 | `-= dt`, `-= delta`, `-= _dt`, or `x = x - dt` on one name, in the sim scope | ADR-0004 `float_duration_countdown` |
| MATH-1 | A global `floor`, `ceil`, `abs`, `sign`, `round`, `sin`, `cos`, `tan`, `atan2`, `pow`, `exp`, `log`, `fmod`, `fposmod`, `lerp`, `move_toward` or `snapped` call in the sim scope | ADR-0004 `sim_nondeterministic_math` |
| MATH-2 | `.distance_to(`, `.distance_squared_to(`, `.normalized(`, `.direction_to(`, `.angle_to(`, `.rotated(`, `.limit_length(`, `.dot(`, `.cross(` in the sim scope | ADR-0004; ADR-0009 |
| MATH-3 | `RandomNumberGenerator`, or a global `randi`, `randf`, `randi_range`, `randf_range`, `randfn`, `randomize`, `seed` call, in the sim scope | ADR-0004 `engine_rng_in_sim` |
| MATH-4 | `RandomNumberGenerator`, `SimRng`, `sim_rng`, or a global `randi`, `randf`, `randi_range`, `randf_range`, `randfn`, `randomize`, `seed` call appears under `src/presentation/`. The data field name `rng_seed` is allowed: it is a copied integer (`Battle.rng_seed`, `ResultSnapshot.rng_seed`, the dev-log key of ADR-0010), not an RNG, and banning the name forced a string trick in `RunLog` | ADR-0004 |
| MATH-6 | In the sim scope, a member typed `Vector2` or initialised `:= Vector2(` | ADR-0009 `sim_position_representation` |

(MATH-5 is withdrawn: ADR-0004 bans instance IDs and hashes only in ordering and payloads, which text cannot tell; the determinism test covers it.)

### Physics

| ID | Fails when | Source |
|---|---|---|
| PHYS-1 | Anywhere in `src/` (in `.gd`, or as a `.tscn` node type): `Area2D`, `CollisionShape2D`, `CollisionPolygon2D`, `PhysicsBody2D`, `StaticBody2D`, `RigidBody2D`, `CharacterBody2D`, `AnimatableBody2D`, `RayCast2D`, `ShapeCast2D`, `PhysicsServer2D`, `direct_space_state`, `PhysicsDirectSpaceState2D`, `PhysicsPointQueryParameters2D`, `PhysicsRayQueryParameters2D`, `PhysicsShapeQueryParameters2D`, or a call to `intersect_point(`, `intersect_ray(`, `intersect_shape(` | ADR-0007 Decision 8 (owner; TR-state-003; ADR-0004 Constraints "no physics areas") |

PHYS-1 self-test (Section 5). Bad sample: `var zone := Area2D.new()` in a file under `src/feature/`; the finding is on that line. Near misses: `Area2D` in a comment, and in a string.

### Input and display

| ID | Fails when | Source |
|---|---|---|
| INPUT-1 | `_input` or `_unhandled_input` is declared outside `src/foundation/input/input_adapter.gd` | ADR-0003 `engine_input_outside_adapter` |
| INPUT-3 | Outside `input_adapter.gd`, an `Input.` call whose name contains `mouse`, `touch`, `screen` or `pointer` (pointer polling) | ADR-0003 |
| INPUT-4 | In the battle scope, `InputEventMouse` appears | ADR-0003 `mouse_event_in_battle_code` |
| INPUT-5 | In the battle scope, `extends` a `BaseButton` type, `<Button type>.new(`, or a `.tscn` node `type="Button"` (also `CheckBox`, `CheckButton`, `LinkButton`, `MenuButton`, `OptionButton`, `TextureButton`, `ColorPickerButton`) | ADR-0003 (`Button.pressed` ban) |
| INPUT-6 | `.device` is compared with `==` or `!=` to a number literal | ADR-0003 `device_id_literal` |
| INPUT-7 | In the battle scope, `Camera2D` (in `.gd` or as a `.tscn` node type), `canvas_transform =` or `set_canvas_transform(` | ADR-0003 `battle_camera_or_canvas_transform` |
| INPUT-8 | Outside `input_adapter.gd`, `DisplayServer.get_display_safe_area`, `DisplayServer.screen_get_dpi`, `DisplayServer.screen_get_scale`, `DisplayServer.window_get_size` or `DisplayServer.window_get_position` | ADR-0003 `safe_area_source` |
| INPUT-9 | `InputResolver.new(` outside `input_resolver.gd` (tests are outside `src/`) | ADR-0008 Validation 7 (**pending ADR-0008; verify against final ADR-0008**) |
| INPUT-10 | In `input_resolver.gd`, a `Vector2` method call or a member typed `Dictionary` | ADR-0008 Validation 7 (**pending; verify against final ADR-0008**; Vector2 operators are code review) |
| REND-1 | Under `src/presentation/` or in the BattleWrapper scene: `material =`, `ShaderMaterial`, `CanvasItemMaterial`, a `.gdshader` reference, `Light2D`, `PointLight2D`, `CanvasModulate`, `GPUParticles2D`, `CPUParticles2D` | ADR-0011 Decision 7 |
| REND-2 | Under `src/presentation/` (dev overlay excepted) or in the BattleWrapper scene: `CanvasLayer`, `z_index =` with a non-zero value, `z_as_relative`, `top_level = true`, `Line2D`, `Polygon2D`, `Sprite2D` (modal screen scenes excepted) | ADR-0011 Decision 1 |
| REND-3 | Under `src/presentation/`: `instantiate(` outside an `attach` method; `antialiased = true` or a literal `true` in the antialiased argument position is code review | ADR-0011 Decisions 4, 6 (partial) |

(INPUT-2 is withdrawn: ADR-0003 says modal screens read events in `_gui_input`, not that no other Control may; SCENE-1 proves the other Controls ignore input.)

### Errors

| ID | Fails when | Source |
|---|---|---|
| ERR-1 | `assert(` appears | C5 [owner: code review; ADR-0001 bans it for release-relevant checks only] |
| ERR-3 | `push_warning(` appears | ADR-0007 Decision 7 |
| ERR-4 | `.free()` or a bare `free()` appears (`queue_free()` is not matched), on any object | C5 [owner: code review; ADR-0001 bans `free()` on a node in the current input or signal call] |
| ERR-5 | `preload(` in `src/root/app_root.gd` | ADR-0001 `app_root_scene_loading` |

(ERR-2 is withdrawn: ADR-0001 bars `print_debug` from carrying error reports, not from use; code review.)

### Construction

| ID | Fails when | Source |
|---|---|---|
| INIT-1 | Under `src/` or `tests/`: a script `extends` a project class (class index) whose `_init` has a parameter with no default, and declares its own `func _init(` whose body has no `super(` call. A script with no `_init` of its own is not matched (the engine then checks the arguments, ADR-0009 V7) | ADR-0009 V7 (the engine does not enforce forwarding: a missing `super(...)` builds silently with the parent's fields at their defaults, 2026-11-04); ADR-0010 `InertHeroSim` |

INIT-1 self-test (Section 5). Bad sample: `extends Targetable` (whose `_init(p_spawn_id: int)` has no default) with `func _init(p_spawn_id: int, p_def_id: StringName) -> void:` and a body of `def_id = p_def_id`; the finding is on the `func _init(` line. Near misses (no finding): the same file with `super(p_spawn_id)` as the body's first line; a subclass of `Targetable` with no `_init`; a subclass of a class whose `_init` arguments all have defaults; `extends RefCounted` with an `_init` and no `super(`. A second bad sample: the `super(p_spawn_id)` appears only in a comment or a string (masked, so it does not count).

### Tests

| ID | Fails when | Source |
|---|---|---|
| TEST-1 | Under `tests/`: `assert_signal(` or `monitor_signals(` | TR-input-014 |
| TEST-2 | Under `tests/unit/`: `FileAccess`, `DirAccess`, `ConfigFile`, `ResourceLoader`, or `load(`/`preload(` of a path not ending `.gd` | TR-data-012 |
| TEST-3 | Under `tests/unit/`: `.tscn`, `instantiate(` or `scene_runner(` | TR-enemy-014 |
| TEST-4 | Under `tests/`: one file holds both `baselines` and `FileAccess.WRITE` or `FileAccess.READ_WRITE` | ADR-0004 Decision 9 |
| TEST-5 | Under `tests/`: a gdUnit4 `simulate_` call | ADR-0007 Decision 3 |
| TEST-6 | Under `tests/`: a test or suite function has a `do_skip` or `skip_reason` parameter, or a `test_` function has a parameter other than `timeout`, `fuzzer_iterations`, `fuzzer_seed`, `test_parameters`, a parameter-set argument (when `test_parameters` is present) or a `Fuzzer`-typed one. gdUnit4 6.2.0 **silently skips** a test with an unknown parameter (`GdUnitTestSuiteScanner.gd` lines 207 to 211) | `coding-standards.md` (never skip failing tests) |

### Project files

| ID | Fails when | Source |
|---|---|---|
| PROJ-1 | `project.godot` has an `[autoload]` section | ADR-0001 V5 |
| PROJ-2 | `src/root/app_root.tscn` exists and `[application]` lacks `run/main_scene="res://src/root/app_root.tscn"` | ADR-0001 Decision 1 |
| PROJ-3 | A key of ADR-0003 Decisions 3 and 4 is missing or differs: `config/quit_on_go_back=false`; `window/size/viewport_width=540`, `viewport_height=960`, `mode.mobile=3`; `window/stretch/mode="canvas_items"`, `aspect="keep"`; `window/handheld/orientation=1`; `input_devices/pointing/emulate_touch_from_mouse=true`, `emulate_mouse_from_touch=true` | ADR-0003 (keys NEEDS VERIFICATION there, SP0) |
| PROJ-4 | `[application]` lacks `run/delta_smoothing=false`, or has `run/low_processor_mode=true` | ADR-0004 (key NEEDS VERIFICATION there, V9) |
| PROJ-5 | `[gdunit4]` lacks `report/godot/push_error=true` or `report/verbose_orphans=true`, or sets `report/godot/script_error=false` | ADR-0007 Decision 7; engine check E1 (exit 101 needs orphan reporting) |
| PROJ-6 | `export_presets.cfg` exists and a `[preset.N]` `include_filter` lacks `*.json` | ADR-0002 Validation 10 (key V7) |
| PROJ-7 | `export_presets.cfg` exists and a preset's `exclude_filter` lacks `tests/*`, `tools/*`, `addons/gdUnit4/*` or `prototypes/*` | ADR-0007 Decision 1 (key and relative form V7) |

## 4. Known blind spots

The lint sees names in text, not types. Not seen: access through untyped variables, `get_node`,
`Object.call`, `get` or `set`; a roster array kept in a variable and mutated later; `Dictionary`
iteration order; field writes through a differently named receiver; `Vector2` operators. These
stay on the tests and code-review rows of ADR-0007 Decision 9.

## 5. Self-test obligations

`tests/unit/lint/lint_rules_test.gd` iterates this catalogue's IDs as mirrored in
`lint_rules.gd`. Each active rule needs one seeded bad sample that yields exactly its finding on
the expected line, and at least one near miss (the token in a comment, in a string, in an
allowed file, out of scope) that yields none. The lexer additionally has cases for `\"` escapes,
`#` inside triple quotes, `$"..."` and `%"..."`, a multi-line lambda under `tests/`, and a joined
continuation line. A rule with no bad sample fails the suite.
