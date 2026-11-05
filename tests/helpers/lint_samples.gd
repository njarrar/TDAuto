extends RefCounted
## Seeded bad samples and near misses for every lint rule (ADR-0007 Validation 2).
##
## A source sample is {kind: "source", cases: [[path, text, line], ...], near: [[path, text], ...],
## others: {path: text}}. "others" are extra files that feed the class index only.
## A project sample is {kind: "project", cases: [[files, line], ...], near: [files, ...]}.
## Each bad case must give exactly one finding of its rule, on its line (project rules:
## one or more, all on its line). Each near miss must give none of that rule.

const LintEngine := preload("res://tools/lint/lint_engine.gd")

const CONTRACT: String = "res://tests/integration/battle_wiring/battle_signal_contract.gd"
const CONTRACT_TEXT: String = 'const WIRING := {\n\t"enemy_wave.enemy_killed": [["tower_sim", &"on_enemy_killed"]],\n\t"input_resolver.tapped": [],\n}\n'

const GOOD_PROJECT: String = (
	"config_version=5\n\n[application]\n\n"
	+ 'config/name="TowerRiot"\nconfig/quit_on_go_back=false\n'
	+ 'run/main_scene="res://src/root/app_root.tscn"\nrun/delta_smoothing=false\n\n'
	+ "[display]\n\nwindow/size/viewport_width=540\nwindow/size/viewport_height=960\n"
	+ 'window/size/mode.mobile=3\nwindow/stretch/mode="canvas_items"\nwindow/stretch/aspect="keep"\n'
	+ "window/handheld/orientation=1\n\n"
	+ "[gdunit4]\n\nreport/godot/push_error=true\nreport/godot/script_error=true\nreport/verbose_orphans=true\n\n"
	+ "[input_devices]\n\npointing/emulate_touch_from_mouse=true\npointing/emulate_mouse_from_touch=true\n"
)
const SCENE_FILE: String = "res://src/root/app_root.tscn"
const GOOD_PRESET: String = '[preset.0]\n\nname="Android"\ninclude_filter="*.json"\nexclude_filter="tests/*, tools/*, addons/gdUnit4/*, prototypes/*"\n'


## Every sample, keyed by rule ID.
static func all() -> Dictionary:
	var s: Dictionary = {}
	var tower: Dictionary = {"res://src/feature/tower/tower_sim.gd": "class_name TowerSim\nextends RefCounted\n"}
	var hero: Dictionary = {"res://src/feature/hero/hero_sim.gd": "class_name HeroSim\nextends RefCounted\n"}
	var flow: Dictionary = {"res://src/core/flow.gd": "class_name Flow\nextends RefCounted\n"}
	var contract: Dictionary = {CONTRACT: CONTRACT_TEXT}
	var core: String = "res://src/core/probe.gd"
	var pres: String = "res://src/presentation/probe.gd"
	var root: String = "res://src/root/probe.gd"
	var unit: String = "res://tests/unit/probe/probe_test.gd"

	# LAYER
	_src(s, "LAYER-1", core, "extends RefCounted\nvar t: TowerSim = null\n", 2, [
		[root, "extends RefCounted\nvar t: TowerSim = null\n"],
		[core, "extends RefCounted\n# uses TowerSim\nvar s: String = \"TowerSim\"\n"],
		["res://src/feature/x/probe.gd", "extends RefCounted\nvar f: Flow = null\n"],
	], _merge(tower, flow), [
		["res://src/core/scene_probe.tscn", '[gd_scene format=3]\n\n[ext_resource type="Script" path="res://src/feature/tower/tower_sim.gd" id="1"]\n', 3],
	])
	_src(s, "LAYER-2", "res://src/feature/tower/tower_probe.gd", "extends RefCounted\nvar h: HeroSim = null\n", 2, [
		["res://src/feature/hero/hero_probe.gd", "extends RefCounted\nvar h: HeroSim = null\n"],
		["res://src/feature/tower/tower_probe.gd", "extends RefCounted\nvar f: Flow = null\n"],
		["res://src/feature/tower/tower_probe.gd", "extends RefCounted\n# HeroSim\n"],
	], _merge(hero, flow))
	_src(s, "LAYER-3", "res://src/stray.gd", "extends RefCounted\n", 1, [
		[core, "extends RefCounted\n"],
		["res://src/core/ok.tscn", "[gd_scene format=3]\n"],
	])
	_src(s, "LAYER-4", core, 'const H := preload("res://tests/helpers/fakes.gd")\n', 1, [
		[core, 'const H := preload("res://src/foundation/x.gd")\n'],
		[core, 'var s: String = "res://tests/helpers/fakes.gd"\n'],
		[core, '# preload("res://tools/lint/lint_rules.gd")\n'],
	])
	_src(s, "LAYER-5", core, 'const H := preload("uid://abc123")\n', 1, [
		[core, 'const H := preload("res://src/core/x.gd")\n'],
		[core, "# uid://abc123\n"],
	])

	# NAME
	_src(s, "NAME-1", "res://src/core/foo.gd", "class_name Foo\nextends RefCounted\n", 1, [
		["res://src/core/foo.gd", "class_name Foo\nextends RefCounted\n"],
	], {"res://tests/helpers/foo_dup.gd": "class_name Foo\n"}, [])
	# The near miss of NAME-1 needs different others, so it is added below.
	s["NAME-1"]["near_others"] = {"res://tests/helpers/bar.gd": "class_name Bar\n", "res://tests/helpers/note.gd": "# class_name Foo\n"}
	_src(s, "NAME-2", "res://src/core/node.gd", "class_name Node\nextends RefCounted\n", 1, [
		["res://src/core/tower_sim.gd", "class_name TowerSim\nextends RefCounted\n"],
	])
	_src(s, "NAME-3", "res://tests/helpers/probe.gd", "class_name Probe\nextends RefCounted\n", 1, [
		[core, "class_name Probe\nextends RefCounted\n"],
		["res://tests/helpers/probe.gd", "# class_name Probe\nextends RefCounted\n"],
	])
	_src(s, "NAME-4", "res://src/core/tower_sim.gd", "class_name TowerSimulator\nextends RefCounted\n", 1, [
		["res://src/core/tower_sim.gd", "class_name TowerSim\nextends RefCounted\n"],
	])
	_src(s, "NAME-5", core, "func load(path: String) -> void:\n\tpass\n", 1, [
		[core, "func loader(seed_value: int) -> void:\n\tpass\n"],
		[core, "# func load(x)\nvar a: int = 1\n"],
	], {}, [
		[core, "func f(seed: int) -> void:\n\tpass\n", 1],
		[core, "func f() -> void:\n\tvar seed: int = 1\n", 2],
	])

	# WIRE
	_src(s, "WIRE-1", core, "var c: Callable = Callable(self, 'run')\n", 1, [
		[core, "var c: Callable = Callable()\n"],
		[core, "var c: Callable = run\n"],
	])
	_src(s, "WIRE-2", core, 'func _ready() -> void:\n\tsig.connect("x", cb)\n', 2, [
		[core, "func _ready() -> void:\n\tsig.connect(cb)\n"],
		[core, '# sig.connect("x", cb)\n'],
		[core, 'var s: String = "emit_signal(x)"\n'],
	], {}, [
		[core, 'func f() -> void:\n\temit_signal(&"x")\n', 2],
	])
	_src(s, "WIRE-3", core, "func _ready() -> void:\n\tvar f: Callable = func() -> void: pass\n", 2, [
		[core, "func _ready() -> void:\n\tpass\n"],
		[core, "# var f = func():\nvar a: int = 1\n"],
	])
	_src(s, "WIRE-4", core, "func _ready() -> void:\n\tsig.connect(on_x.bind(1))\n", 2, [
		[core, "func _ready() -> void:\n\tvar c: Callable = on_x.bind(1)\n"],
		[core, "func _ready() -> void:\n\tsig.connect(on_x)\n"],
	], {}, [
		["res://src/root/battle_builder.gd", "func f() -> void:\n\tvar c: Callable = on_x.bind(1)\n", 2],
	])
	_src(s, "WIRE-5", "res://src/root/battle_builder.gd", "func build() -> void:\n\tenemy_wave.enemy_killed.connect(tower.on_enemy_killed, CONNECT_DEFERRED)\n", 2, [
		["res://src/root/battle_builder.gd", "func build() -> void:\n\tenemy_wave.enemy_killed.connect(tower.on_enemy_killed)\n"],
		[core, "func f() -> void:\n\tx.some_other.connect(a, CONNECT_ONE_SHOT)\n"],
	], contract)
	_src(s, "WIRE-6", core, "func f() -> void:\n\tenemy_wave.enemy_killed.connect(on_enemy_killed)\n", 2, [
		["res://src/root/battle_builder.gd", "func f() -> void:\n\tenemy_wave.enemy_killed.connect(on_enemy_killed)\n"],
		[core, "func f() -> void:\n\tx.other_signal.connect(on_other_signal)\n"],
	], contract)
	_src(s, "WIRE-7", "res://src/presentation/hud.tscn", '[gd_scene format=3]\n\n[connection signal="enemy_killed" from="A" to="B" method="_on_x"]\n', 3, [
		["res://src/presentation/hud.tscn", '[gd_scene format=3]\n\n[connection signal="pressed" from="A" to="B" method="_on_x"]\n'],
		["res://src/presentation/hud.tscn", "[gd_scene format=3]\n"],
	], contract)
	_src(s, "WIRE-8", "res://src/root/battle_builder.gd", "func build() -> void:\n\tenemy_wave.enemy_killed.connect(tower.handle_kill)\n", 2, [
		["res://src/root/battle_builder.gd", "func build() -> void:\n\tenemy_wave.enemy_killed.connect(tower.on_enemy_killed)\n"],
		["res://src/root/battle_builder.gd", "func build() -> void:\n\tenemy_wave.enemy_killed.connect(view._on_enemy_killed)\n"],
	], contract)
	_src(s, "WIRE-9", "res://src/presentation/hud.gd", "func _on_enemy_killed(bounty: int) -> void:\n\tbattle.tick(1)\n", 2, [
		["res://src/presentation/hud.gd", "func _on_enemy_killed(bounty: int) -> void:\n\tgold += bounty\n"],
		["res://src/presentation/hud.gd", "func _on_tapped(p: Vector2) -> void:\n\tbattle.build(p)\n"],
	], contract)
	_src(s, "WIRE-10", "res://src/core/flow.gd", "class_name Flow\nextends RefCounted\nsignal phase_changed(value)\n", 3, [
		["res://src/core/flow.gd", "class_name Flow\nextends RefCounted\nsignal phase_changed(value: int)\n"],
		["res://src/core/flow.gd", "class_name Flow\nextends RefCounted\nenum Phase { A, B }\nsignal changed(value: Phase, n: int)\n"],
		["res://src/core/other.gd", "extends RefCounted\nsignal s(a)\n"],
	], {}, [
		["res://src/core/flow.gd", "class_name Flow\nextends RefCounted\nsignal moved(label: String)\n", 3],
	])
	_src(s, "WIRE-11", "res://src/foundation/data/record.gd", "extends RefCounted\nsignal changed\n", 2, [
		["res://src/core/record.gd", "extends RefCounted\nsignal changed\n"],
		["res://src/foundation/data/record.gd", "extends RefCounted\n# signal changed\n"],
	])
	_src(s, "WIRE-12", core, 'var enemy_id: String = ""\n', 1, [
		[core, "var enemy_id: StringName = &\"\"\n"],
		[core, 'var title: String = ""\n'],
		[pres, 'var enemy_id: String = ""\n'],
	])

	# STATE and STAT
	_src(s, "STATE-1", core, "static var cache: int = 0\n", 1, [
		[core, "var cache: int = 0\n"],
		[core, "static func f() -> void:\n\tpass\n"],
		[core, "# static var cache: int = 0\n"],
	])
	_src(s, "STATE-2", core, "extends RefCounted\nvar battle: Battle = null\n", 2, [
		[pres, "extends RefCounted\nvar battle: Battle = null\n"],
		[core, "extends RefCounted\nfunc f() -> void:\n\tvar b: Battle = null\n"],
		[core, "extends RefCounted\nvar b: BattleBuilder = null\n"],
	])
	_src(s, "STATE-3", core, "func reset() -> void:\n\tpass\n", 1, [
		[core, "func drop_backlog() -> void:\n\tpass\n"],
		[pres, "func reset() -> void:\n\tpass\n"],
	])
	_src(s, "STATE-4", "res://src/feature/tower/probe.gd", "func f(e: Object) -> void:\n\te.hp -= 3\n", 2, [
		["res://src/core/combat/probe.gd", "func f(e: Object) -> void:\n\te.hp -= 3\n"],
		[core, "func f(e: Object) -> void:\n\tif e.hp == 3:\n\t\tpass\n"],
		[core, "func f(e: Object) -> int:\n\tvar h: int = e.hp\n\treturn h\n"],
	])
	_src(s, "STATE-5", core, "func f() -> void:\n\twave.add_enemy(e)\n", 2, [
		["res://src/feature/enemy_wave/probe.gd", "func f() -> void:\n\twave.add_enemy(e)\n"],
		[core, "func f() -> void:\n\twave.add_enemy_later(e)\n"],
	])
	_src(s, "STATE-6", core, "func f() -> void:\n\ttargets().append(e)\n", 2, [
		[core, "func f() -> void:\n\tvar t: Array = targets()\n"],
		[core, "func f() -> int:\n\treturn targets().size()\n"],
		[core, "# targets().clear()\nvar a: int = 1\n"],
	])
	_src(s, "STATE-7", "res://src/core/combat/health.gd", "class_name Health\nextends RefCounted\nvar owner: Combat = null\n", 3, [
		["res://src/core/combat/health.gd", "class_name Health\nextends RefCounted\nvar hp: int = 0\n"],
		["res://src/core/combat/other.gd", "class_name Other\nextends RefCounted\nvar c: Combat = null\n"],
		["res://src/core/combat/health.gd", "class_name Health\nextends RefCounted\nvar c: CombatTypes = null\n"],
	])
	_src(s, "STATE-8", core, "func f() -> void:\n\tfor e in items:\n\t\titems.erase(e)\n", 3, [
		[core, "func f() -> void:\n\tfor e in items.duplicate():\n\t\titems.erase(e)\n"],
		[core, "func f() -> void:\n\tfor e in items:\n\t\tother.erase(e)\n"],
	])
	_src(s, "STATE-9", core, "var cells: PackedInt32Array:\n\tset(value):\n\t\tcells = value\nfunc f() -> void:\n\tcells[0] = 1\n", 5, [
		[core, "var cells: PackedInt32Array = PackedInt32Array()\nfunc f() -> void:\n\tcells[0] = 1\n"],
	])
	_src(s, "STATE-10", "res://src/foundation/data/catalogue.gd", "extends RefCounted\nvar hook: Callable\n", 2, [
		["res://src/foundation/data/catalogue.gd", "extends RefCounted\nvar names: Array[StringName] = []\n"],
		["res://src/foundation/data/other.gd", "extends RefCounted\nvar hook: Callable\n"],
	], {}, [
		["res://src/foundation/data/records/tower_record.gd", "extends RefCounted\nvar hook: Callable\n", 2],
	])
	_src(s, "STAT-1", core, 'func f() -> void:\n\tvar v: int = acc.stat_int(id, "hp")\n', 2, [
		[core, "func f() -> void:\n\tvar v: int = acc.stat_int(id, StatKeys.HP)\n"],
		[core, "func stat_int(id: int, key: StringName) -> int:\n\treturn 0\n"],
	])

	# TIME and MATH
	_src(s, "TIME-1", core, "func _physics_process(delta: float) -> void:\n\tpass\n", 1, [
		[core, "func _process(delta: float) -> void:\n\tpass\n"],
		[core, "# func _physics_process(d)\nvar a: int = 1\n"],
	])
	_src(s, "TIME-2", core, "func _process(delta: float) -> void:\n\tpass\n", 1, [
		["res://src/root/battle_wrapper.gd", "func _process(delta: float) -> void:\n\tpass\n"],
		[core, "func _process_input() -> void:\n\tpass\n"],
	])
	_src(s, "TIME-3", core, "func f() -> void:\n\tawait get_tree().process_frame\n", 2, [
		["res://src/root/app_root.gd", "var seed_value: int = Time.get_unix_time_from_system()\n"],
		["res://src/presentation/dev/gesture_log.gd", "var t: int = Time.get_ticks_usec()\n"],
		[core, "var awaiting: bool = false\n"],
	], {}, [
		[core, "var t: int = Time.get_ticks_msec()\n", 1],
		["res://src/root/app_root.gd", "var t: int = Time.get_ticks_usec()\n", 1],
	])
	_src(s, "TIME-4", core, "func f() -> void:\n\tget_tree().paused = true\n", 2, [
		[core, "func f() -> void:\n\tprocess_mode = Node.PROCESS_MODE_ALWAYS\n"],
	])
	_src(s, "TIME-5", core, "func tick(dt: float) -> void:\n\tleft -= dt\n", 2, [
		[core, "func tick(dt: int) -> void:\n\tleft = left - 1\n"],
		[pres, "func tick(dt: float) -> void:\n\tleft -= dt\n"],
	], {}, [
		[core, "func tick(dt: float) -> void:\n\tleft = left - dt\n", 2],
	])
	_src(s, "MATH-1", core, "func f(x: float) -> float:\n\treturn floor(x)\n", 2, [
		[core, "func f(x: Vector2) -> Vector2:\n\treturn x.floor()\n"],
		[core, "func floor(x: int) -> int:\n\treturn x\n"],
		[core, "func f(x: float) -> int:\n\treturn floori(x)\n"],
	])
	_src(s, "MATH-2", core, "func f(a: Vector2, b: Vector2) -> float:\n\treturn a.distance_to(b)\n", 2, [
		[pres, "func f(a: Vector2, b: Vector2) -> float:\n\treturn a.distance_to(b)\n"],
		[core, "func f(a: Object, b: Object) -> int:\n\treturn a.distance_x(b)\n"],
	])
	_src(s, "MATH-3", core, "func f() -> int:\n\treturn randi()\n", 2, [
		[core, "func f() -> int:\n\treturn rng.randi()\n"],
		[pres, "func f() -> int:\n\treturn randi()\n"],
	], {}, [
		[core, "var r: RandomNumberGenerator = null\n", 1],
	])
	_src(s, "MATH-4", pres, "var s: int = sim_rng.state\n", 1, [
		[core, "var s: int = sim_rng.state\n"],
		[pres, "var rng_seeded: bool = false\n"],
	])
	_src(s, "MATH-6", core, "extends RefCounted\nvar pos: Vector2 = Vector2.ZERO\n", 2, [
		[core, "extends RefCounted\nfunc f() -> void:\n\tvar p: Vector2 = Vector2.ZERO\n"],
		[core, "extends RefCounted\nvar cell: Vector2i = Vector2i.ZERO\n"],
	])

	# INPUT and REND
	_src(s, "INPUT-1", core, "func _input(event: InputEvent) -> void:\n\tpass\n", 1, [
		["res://src/foundation/input/input_adapter.gd", "func _input(event: InputEvent) -> void:\n\tpass\n"],
		[core, "func _inputs() -> void:\n\tpass\n"],
	])
	_src(s, "INPUT-3", core, "func f() -> bool:\n\treturn Input.is_mouse_button_pressed(1)\n", 2, [
		[core, "func f() -> bool:\n\treturn Input.is_action_pressed(&\"x\")\n"],
		["res://src/foundation/input/input_adapter.gd", "func f() -> bool:\n\treturn Input.is_mouse_button_pressed(1)\n"],
	])
	_src(s, "INPUT-4", pres, "func f(e: InputEvent) -> void:\n\tif e is InputEventMouseButton:\n\t\tpass\n", 2, [
		["res://src/root/app_root.gd", "func f(e: InputEvent) -> void:\n\tif e is InputEventMouseButton:\n\t\tpass\n"],
		[pres, "func f(e: InputEvent) -> void:\n\tif e is InputEventScreenTouch:\n\t\tpass\n"],
	])
	_src(s, "INPUT-5", pres, "extends Button\n", 1, [
		[pres, "extends Label\n"],
		[pres, "extends ButtonGroup\n"],
		["res://src/presentation/hud.tscn", '[gd_scene format=3]\n\n[node name="A" type="Label"]\n'],
	], {}, [
		[pres, "func f() -> void:\n\tvar b: CheckBox = CheckBox.new()\n", 2],
		["res://src/presentation/hud.tscn", '[gd_scene format=3]\n\n[node name="A" type="Button"]\n', 3],
	])
	_src(s, "INPUT-6", core, "func f(e: InputEventScreenTouch) -> bool:\n\treturn e.device == 0\n", 2, [
		[core, "func f(e: InputEventScreenTouch) -> bool:\n\treturn e.device == pointer_id\n"],
	])
	_src(s, "INPUT-7", pres, "var cam: Camera2D = null\n", 1, [
		[pres, "var cam: Camera3D = null\n"],
		["res://src/root/app_root.gd", "var cam: Camera2D = null\n"],
	], {}, [
		["res://src/presentation/field.tscn", '[gd_scene format=3]\n\n[node name="Cam" type="Camera2D"]\n', 3],
		[pres, "func f(c: CanvasItem) -> void:\n\tc.get_viewport().canvas_transform = Transform2D.IDENTITY\n", 2],
	])
	_src(s, "INPUT-8", core, "var r: Rect2i = DisplayServer.get_display_safe_area()\n", 1, [
		["res://src/foundation/input/input_adapter.gd", "var r: Rect2i = DisplayServer.get_display_safe_area()\n"],
		[core, "var n: String = DisplayServer.get_name()\n"],
	])
	_src(s, "INPUT-9", root, "func f() -> void:\n\tvar r: InputResolver = InputResolver.new()\n", 2, [
		["res://src/foundation/input/input_resolver.gd", "func f() -> void:\n\tvar r: InputResolver = InputResolver.new()\n"],
	])
	_src(s, "INPUT-10", "res://src/foundation/input/input_resolver.gd", "func f(a: Vector2) -> float:\n\treturn a.length()\n", 2, [
		["res://src/foundation/input/other.gd", "func f(a: Vector2) -> float:\n\treturn a.length()\n"],
		["res://src/foundation/input/input_resolver.gd", "func f(a: float, b: float) -> float:\n\treturn a + b\n"],
	], {}, [
		["res://src/foundation/input/input_resolver.gd", "var table: Dictionary = {}\n", 1],
	])
	_src(s, "REND-1", pres, "var m: ShaderMaterial = null\n", 1, [
		[pres, "var m: Label = null\n"],
		[core, "var m: ShaderMaterial = null\n"],
		[pres, "func f(x: Node) -> void:\n\tx.material_override = null\n"],
	], {}, [
		[pres, 'var s: Shader = preload("res://assets/x.gdshader")\n', 1],
		["res://src/presentation/hud.tscn", '[gd_scene format=3]\n\n[sub_resource type="ShaderMaterial" id="a"]\n', 3],
	])
	_src(s, "REND-2", pres, "var l: CanvasLayer = null\n", 1, [
		[pres, "func f(n: Node2D) -> void:\n\tn.z_index = 0\n"],
		["res://src/presentation/screens/menu.gd", "var s: Sprite2D = null\n"],
		["res://src/presentation/dev/probe.gd", "var l: CanvasLayer = null\n"],
		[pres, "var s: Sprite3D = null\n"],
	], {}, [
		[pres, "func f(n: Node2D) -> void:\n\tn.z_index = 3\n", 2],
		[pres, "var s: Sprite2D = null\n", 1],
		["res://src/presentation/hud.tscn", '[gd_scene format=3]\n\n[node name="A" type="Line2D"]\n', 3],
	])
	_src(s, "REND-3", pres, "func build() -> void:\n\tvar n: Node = scene.instantiate()\n", 2, [
		[pres, "func attach() -> void:\n\tvar n: Node = scene.instantiate()\n"],
	])
	_src(s, "REND-4", core, "var m: ShaderMaterial = null\n", 1, [
		[core, "func f() -> void:\n\tvar e: Variant = Shader\n"],
		[core, 'var s: String = "use a shader"\n'],
		[unit, "var m: ShaderMaterial = null\n"],
	], {}, [
		[core, "func f() -> void:\n\tvar e := Environment.new()\n", 2],
		[core, 'const S := preload("res://assets/x.gdshader")\n', 1],
		["res://src/presentation/hud.tscn", '[gd_scene format=3]\n\n[sub_resource type="Environment" id="a"]\n', 3],
	])

	# ERR and INIT
	_src(s, "ERR-1", core, "func f(x: int) -> void:\n\tassert(x > 0)\n", 2, [
		[core, "func f(x: int) -> void:\n\tvar y: int = x # assert(x)\n"],
		[core, "func f(x: int) -> void:\n\tassert_x(x)\n"],
	])
	_src(s, "ERR-3", core, "func f() -> void:\n\tpush_warning(\"x\")\n", 2, [
		[core, "func f() -> void:\n\tpush_error(\"x\")\n"],
	])
	_src(s, "ERR-4", core, "func f(n: Node) -> void:\n\tn.free()\n", 2, [
		[core, "func f(n: Node) -> void:\n\tn.queue_free()\n"],
		[core, "func free_all() -> void:\n\tpass\n"],
	])
	_src(s, "ERR-5", "res://src/root/app_root.gd", 'const S := preload("res://src/root/x.gd")\n', 1, [
		["res://src/root/battle_builder.gd", 'const S := preload("res://src/root/x.gd")\n'],
	])
	var init_others: Dictionary = {
		"res://src/core/combat/targetable.gd": "class_name Targetable\nextends RefCounted\nfunc _init(p_spawn_id: int) -> void:\n\tpass\n",
		"res://src/core/base.gd": "class_name Base\nextends RefCounted\nfunc _init(a: int = 0) -> void:\n\tpass\n",
	}
	var enemy: String = "res://src/feature/enemy_wave/enemy.gd"
	_src(s, "INIT-1", enemy, "class_name Enemy\nextends Targetable\nvar def_id: StringName\nfunc _init(p_spawn_id: int, p_def_id: StringName) -> void:\n\tdef_id = p_def_id\n", 4, [
		[enemy, "class_name Enemy\nextends Targetable\nvar def_id: StringName\nfunc _init(p_spawn_id: int, p_def_id: StringName) -> void:\n\tsuper(p_spawn_id)\n\tdef_id = p_def_id\n"],
		[enemy, "class_name Enemy\nextends Targetable\nvar def_id: StringName\n"],
		[enemy, "class_name Enemy\nextends Base\nfunc _init(b: int) -> void:\n\tpass\n"],
		[enemy, "class_name Enemy\nextends RefCounted\nfunc _init(b: int) -> void:\n\tpass\n"],
	], init_others, [
		[enemy, "class_name Enemy\nextends Targetable\nvar def_id: StringName\nfunc _init(p_spawn_id: int, p_def_id: StringName) -> void:\n\t# super(p_spawn_id)\n\tdef_id = p_def_id\n", 4],
		[enemy, "class_name Enemy\nextends Targetable\nfunc _init(p_spawn_id: int) -> void:\n\tvar s: String = \"super(p_spawn_id)\"\n", 3],
	])

	# PHYS
	var phys: String = "res://src/feature/probe.gd"
	_src(s, "PHYS-1", phys, "func f() -> void:\n\tvar zone := Area2D.new()\n", 2, [
		[phys, "func f() -> void:\n\t# an Area2D would be wrong here\n\tpass\n"],
		[phys, "func f() -> void:\n\tvar s: String = \"Area2D\"\n"],
	])

	# TEST
	_src(s, "TEST-1", unit, "func test_a() -> void:\n\tassert_signal(obj)\n", 2, [
		[unit, "func test_a() -> void:\n\tassert_that(1)\n"],
	])
	_src(s, "TEST-2", unit, 'func test_a() -> void:\n\tvar f := FileAccess.open("a", 1)\n', 2, [
		[unit, 'const S := preload("res://tests/helpers/fakes.gd")\n'],
		["res://tests/integration/probe/probe_test.gd", 'func test_a() -> void:\n\tvar f := FileAccess.open("a", 1)\n'],
	], {}, [
		[unit, 'const S := preload("res://data/x.json")\n', 1],
	])
	_src(s, "TEST-3", unit, "var n: Node = scene.instantiate()\n", 1, [
		[unit, 'var p: String = "res://a.gd"\n'],
		["res://tests/integration/probe/probe_test.gd", "var n: Node = scene.instantiate()\n"],
	], {}, [
		[unit, 'var p: String = "res://a.tscn"\n', 1],
	])
	_src(s, "TEST-4", unit, 'const P := "res://tests/baselines/x.json"\nfunc test_w() -> void:\n\tvar f := FileAccess.open(P, FileAccess.WRITE)\n', 3, [
		[unit, 'const P := "res://tests/baselines/x.json"\nfunc test_w() -> void:\n\tvar f := FileAccess.open(P, FileAccess.READ)\n'],
		[unit, 'func test_w() -> void:\n\tvar f := FileAccess.open("a", FileAccess.WRITE)\n'],
	])
	_src(s, "TEST-5", unit, "func test_a() -> void:\n\tsimulate_mouse_move(Vector2.ZERO)\n", 2, [
		[unit, "func test_a() -> void:\n\tvar simulated: int = 1\n"],
	])
	_src(s, "TEST-6", unit, "func test_a(do_skip := true) -> void:\n\tpass\n", 1, [
		[unit, "func test_c(timeout := 2000) -> void:\n\tpass\n"],
		[unit, "func test_d(a: int, b: int, test_parameters := [[1, 2]]) -> void:\n\tpass\n"],
		[unit, "func test_e(fuzzer := Fuzzers.rangei(1, 5)) -> void:\n\tpass\n"],
		[unit, "func helper(x: int) -> void:\n\tpass\n"],
	], {}, [
		[unit, "func test_b(extra: int) -> void:\n\tpass\n", 1],
	])

	# PROJECT
	var scene_files: Dictionary = {SCENE_FILE: ""}
	_proj(s, "PROJ-1", GOOD_PROJECT + '\n[autoload]\n\nX="*res://x.gd"\n', "[autoload]", [GOOD_PROJECT], {})
	var bad_main: String = GOOD_PROJECT.replace('run/main_scene="res://src/root/app_root.tscn"', 'run/main_scene="res://other.tscn"')
	_proj(s, "PROJ-2", bad_main, "run/main_scene", [GOOD_PROJECT], scene_files, [bad_main])
	_proj(s, "PROJ-3", GOOD_PROJECT.replace("window/size/viewport_width=540", "window/size/viewport_width=541"), "viewport_width", [GOOD_PROJECT], {})
	_proj(s, "PROJ-4", GOOD_PROJECT.replace("run/delta_smoothing=false", "run/delta_smoothing=true"), "run/delta_smoothing", [GOOD_PROJECT], {})
	_proj(s, "PROJ-5", GOOD_PROJECT.replace("report/verbose_orphans=true", "report/verbose_orphans=false"), "report/verbose_orphans", [GOOD_PROJECT], {})
	var bad_include: String = GOOD_PRESET.replace('include_filter="*.json"', 'include_filter="*.png"')
	var bad_exclude: String = GOOD_PRESET.replace('exclude_filter="tests/*, tools/*, addons/gdUnit4/*, prototypes/*"', 'exclude_filter="tests/*"')
	s["PROJ-6"] = _preset_sample(bad_include, "include_filter", GOOD_PRESET)
	s["PROJ-7"] = _preset_sample(bad_exclude, "exclude_filter", GOOD_PRESET)
	var good_render: String = GOOD_PROJECT.replace("run/delta_smoothing=false\n", "run/delta_smoothing=false\nrun/max_fps=60\n") + (
		'\n[rendering]\n\nrenderer/rendering_method="mobile"\nrendering_device/fallback_to_opengl3=false\n')
	_proj(s, "PROJ-8", good_render.replace("run/max_fps=60", "run/max_fps=0"), "run/max_fps", [good_render], {})
	return s


## Failure lines for a rule's bad cases (empty when every bad case behaves).
static func check_bad(rule: String, sample: Dictionary) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	for case_entry in sample["cases"]:
		var found: Array[Dictionary] = _bad_findings(rule, sample, case_entry)
		var expected_line: int = int(case_entry[2]) if sample["kind"] == "source" else int(case_entry[1])
		if found.is_empty():
			failures.append("%s: a bad case gave no finding (expected line %d)" % [rule, expected_line])
			continue
		if sample["kind"] == "source" and found.size() != 1:
			failures.append("%s: a bad case gave %d findings, expected exactly one" % [rule, found.size()])
		for f in found:
			if int(f["line"]) != expected_line:
				failures.append("%s: finding on line %d, expected %d (%s)" % [rule, int(f["line"]), expected_line, f["message"]])
	return failures


## Failure lines for a rule's near misses (empty when none of them is flagged).
static func check_near(rule: String, sample: Dictionary) -> PackedStringArray:
	var failures: PackedStringArray = PackedStringArray()
	if sample["near"].is_empty():
		failures.append("%s: no near miss" % rule)
	for near_entry in sample["near"]:
		var found: Array[Dictionary] = []
		if sample["kind"] == "source":
			var others: Dictionary = sample.get("near_others", sample["others"])
			found = _source_findings(rule, str(near_entry[0]), str(near_entry[1]), others)
		else:
			found = _project_findings(rule, near_entry)
		for f in found:
			failures.append("%s: near miss flagged on line %d: %s" % [rule, int(f["line"]), f["message"]])
	return failures


static func _bad_findings(rule: String, sample: Dictionary, case_entry: Array) -> Array[Dictionary]:
	if sample["kind"] == "source":
		return _source_findings(rule, str(case_entry[0]), str(case_entry[1]), sample["others"])
	return _project_findings(rule, case_entry[0])


static func _source_findings(rule: String, path: String, text: String, others: Dictionary) -> Array[Dictionary]:
	var sources: Dictionary = others.duplicate()
	sources[path] = text
	var index: Dictionary = LintEngine.build_index(sources)
	var all_findings: Array[Dictionary] = LintEngine.check_source(path, text, index, {"include_pending": true})
	return _only_rule(rule, all_findings)


static func _project_findings(rule: String, files: Dictionary) -> Array[Dictionary]:
	# Pending project rules run here too (PROJ-8), as pending source rules do above.
	return _only_rule(rule, LintEngine.check_project(files, {"include_pending": true}))


static func _only_rule(rule: String, all_findings: Array[Dictionary]) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	for f in all_findings:
		if str(f["rule"]) == rule:
			picked.append(f)
	return picked


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate()
	out.merge(b)
	return out


static func _line_of(text: String, needle: String) -> int:
	return text.substr(0, text.find(needle)).count("\n") + 1


## Adds a source sample. extras: more bad cases as [path, text, line].
static func _src(s: Dictionary, rule: String, path: String, bad: String, line: int, near: Array, others: Dictionary = {}, extras: Array = []) -> void:
	var cases: Array = [[path, bad, line]]
	cases.append_array(extras)
	s[rule] = {"kind": "source", "cases": cases, "near": near, "others": others}


## Adds a project sample. bad_text goes into res://project.godot; line is where needle sits in it.
static func _proj(s: Dictionary, rule: String, bad_text: String, needle: String, near_texts: Array, extra_files: Dictionary, extra_near_texts: Array = []) -> void:
	var bad_files: Dictionary = extra_files.duplicate()
	bad_files["res://project.godot"] = bad_text
	var near: Array = []
	for near_text in near_texts:
		var files: Dictionary = extra_files.duplicate()
		files["res://project.godot"] = near_text
		near.append(files)
	for near_text in extra_near_texts:
		# Same bad text but without the extra files: the rule does not apply.
		near.append({"res://project.godot": near_text})
	s[rule] = {"kind": "project", "cases": [[bad_files, _line_of(bad_text, needle)]], "near": near}


static func _preset_sample(bad_text: String, needle: String, good_text: String) -> Dictionary:
	return {
		"kind": "project",
		"cases": [[{"res://export_presets.cfg": bad_text}, _line_of(bad_text, needle)]],
		"near": [{"res://export_presets.cfg": good_text}, {}],
	}
