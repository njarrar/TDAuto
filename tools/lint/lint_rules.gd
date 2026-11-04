extends RefCounted
## Rule table, scopes, kept sets and file exceptions for the layer lint.
##
## Mirrors docs/architecture/adr-0007-lint-rules.md. The integration lint test
## fails when the rule IDs here differ from the IDs in that catalogue. All data
## is const. A rule whose "pending" value is not empty is switched off and the
## runner prints "pending: <RULE> (<ADR>)" for it on every run.
##
## Rule fields:
##   adr      owning ADR or document (text only)
##   pending  "" when active, else the ADR the rule waits on
##   scope    scope name, resolved in lint_scope.gd
##   ext      "gd", "tscn", "gd,tscn" or "project"
##   also     extra path entries added to the scope
##   only     when set, the file must also match one entry
##   exclude  files that are outside the rule
##   named    file entries that must exist, else "not assessed"
##   named_classes  class names that must exist, else "not assessed"
##   re / re_member / tscn_re / string_re   generic patterns (see lint_check.gd)
## A path entry is a full res:// path, a folder prefix ending in "/", or a bare
## file name (matched against the file name).

const LAYERS: Dictionary = {
	"foundation": 0,
	"core": 1,
	"feature": 2,
	"presentation": 3,
	"root": 4,
}

## Sim scope (kept set, catalogue Section 2).
const SIM_PREFIXES: Array[String] = [
	"res://src/core/",
	"res://src/feature/",
	"res://src/foundation/data/",
]
const SIM_FILES: Array[String] = [
	"res://src/foundation/sim_time.gd",
	"res://src/foundation/sim_rng.gd",
	"res://src/foundation/fatal_latch.gd",
	"res://src/root/battle.gd",
	"res://src/root/fatal_relay.gd",
	"res://src/root/battle_builder.gd",
]

## Battle scope: every file under src/ except these (catalogue Section 2).
const NON_BATTLE_FILES: Array[String] = [
	"res://src/root/app_root.gd",
	"res://src/root/fatal_screen.tscn",
]
## Folders added by the Vertical Slice Menu and Settings stories. Empty at MVP.
const NON_BATTLE_PREFIXES: Array[String] = []

## Classes behind Battle.EMITTER_KEYS, plus InputAdapter (catalogue Section 2).
const EMITTER_CLASSES: Array[String] = [
	"Flow", "Combat", "EnemyWave", "TowerSim", "HeroSim", "InputResolver", "InputAdapter",
]
## Real-time model classes (ADR-0004 Decision 8). Kept for reference; no active rule needs it.
const REAL_TIME_MODELS: Array[String] = ["HudLogic", "TowerInput", "ChipWindow", "HeroInput"]

const COMMANDS: Array[String] = [
	"pin", "burst", "build", "upgrade", "start_wave", "call_early", "pause", "resume",
]
const GESTURE_SIGNALS: Array[String] = [
	"pressed", "tapped", "ground_tapped", "drag_started", "drag_moved", "drag_ended",
]

## File of battle signals (WIRING and VIEW_ALLOWLIST keys), written by the ADR-0006 story.
const CONTRACT_PATH: String = "res://tests/integration/battle_wiring/battle_signal_contract.gd"

## Modal screen scenes may hold a Sprite2D (REND-2). UNVERIFIED folder: ADR-0011 names no path yet.
const MODAL_SCREEN_PREFIXES: Array[String] = ["res://src/presentation/screens/"]

## Engine names that ClassDB does not report (Variant types), catalogue Section 2.
const VARIANT_NAMES: Array[String] = [
	"bool", "int", "float", "String", "StringName", "NodePath", "Vector2", "Vector2i",
	"Vector3", "Vector3i", "Vector4", "Vector4i", "Rect2", "Rect2i", "Transform2D",
	"Transform3D", "Plane", "Quaternion", "AABB", "Basis", "Projection", "Color", "RID",
	"Object", "Callable", "Signal", "Dictionary", "Array", "PackedByteArray",
	"PackedInt32Array", "PackedInt64Array", "PackedFloat32Array", "PackedFloat64Array",
	"PackedStringArray", "PackedVector2Array", "PackedVector3Array", "PackedColorArray",
	"PackedVector4Array",
]

## Signal parameter types allowed on battle emitters (WIRE-10), besides src enums.
const WIRE10_TYPES: Array[String] = ["int", "float", "bool", "StringName", "Vector2"]

## Exceptions. Each row: rule, file entry, optional allow (match prefixes), the ADR decision.
## No inline suppressions exist. Budget: ten rows by the end of MVP.
const MAX_FILE_EXCEPTIONS: int = 10
const FILE_EXCEPTIONS: Array[Dictionary] = [
	{
		"rule": "TIME-3",
		"file": "res://src/root/app_root.gd",
		"allow": ["Time.get_unix_time_from_system", "Time.get_ticks_msec"],
		"adr": "ADR-0004 V8 (run seed)",
	},
	{
		"rule": "TIME-3",
		"file": "res://src/root/battle_wrapper.gd",
		"allow": ["Time.get_ticks_usec"],
		"adr": "ADR-0004 (dev timers)",
	},
	{
		"rule": "TIME-3",
		"file": "res://src/presentation/dev/",
		"allow": ["Time."],
		"adr": "ADR-0008 GestureLog (verify against final ADR-0008)",
	},
]

## Project keys for PROJ-3: [section, key, expected raw value]. ADR-0003 Decisions 3 and 4.
const PROJ3_KEYS: Array = [
	["application", "config/quit_on_go_back", "false"],
	["display", "window/size/viewport_width", "540"],
	["display", "window/size/viewport_height", "960"],
	["display", "window/size/mode.mobile", "3"],
	["display", "window/stretch/mode", "\"canvas_items\""],
	["display", "window/stretch/aspect", "\"keep\""],
	["display", "window/handheld/orientation", "1"],
	["input_devices", "pointing/emulate_touch_from_mouse", "true"],
	["input_devices", "pointing/emulate_mouse_from_touch", "true"],
]
const PROJ2_SCENE: String = "res://src/root/app_root.tscn"
const PROJ7_EXCLUDES: Array[String] = ["tests/*", "tools/*", "addons/gdUnit4/*", "prototypes/*"]

const _MEMBER_PREFIX: String = r"^(?:@\w+(?:\([^)]*\))?\s+)*"
const _BUTTONS: String = "BaseButton|Button|CheckBox|CheckButton|LinkButton|MenuButton|OptionButton|TextureButton|ColorPickerButton"

## Rule table, in catalogue order.
const RULES: Dictionary = {
	"LAYER-1": {"adr": "architecture.md rules 1-3, 5", "pending": "", "scope": "src", "ext": "gd,tscn", "msg": "higher layer"},
	"LAYER-2": {"adr": "architecture.md rule 4", "pending": "", "scope": "src", "ext": "gd,tscn", "msg": "other feature module"},
	"LAYER-3": {"adr": "architecture.md rule 6", "pending": "", "scope": "src", "ext": "gd,tscn", "msg": "outside the five layer folders"},
	"LAYER-4": {"adr": "architecture.md rule 2; ADR-0007", "pending": "", "scope": "src", "ext": "gd,tscn", "msg": "references addons, tests, tools or prototypes"},
	"LAYER-5": {"adr": "ADR-0007 (E2)", "pending": "", "scope": "src", "ext": "gd", "msg": "uid:// path in src"},
	"NAME-1": {"adr": "QQ-16", "pending": "", "scope": "scan", "ext": "gd", "msg": "duplicate class_name"},
	"NAME-2": {"adr": "QQ-16", "pending": "", "scope": "src", "ext": "gd", "msg": "class_name is an engine name"},
	"NAME-3": {"adr": "ADR-0007 Decision 1", "pending": "", "scope": "tests_tools", "ext": "gd", "msg": "class_name outside src"},
	"NAME-4": {"adr": "project.yaml naming", "pending": "", "scope": "src", "ext": "gd", "msg": "class_name differs from file name"},
	"NAME-5": {"adr": "ADR-0002; ADR-0001", "pending": "", "scope": "src", "ext": "gd", "msg": "name shadows a global function"},
	"WIRE-1": {"adr": "ADR-0001 Decision 5", "pending": "", "scope": "src", "ext": "gd", "msg": "Callable built from arguments", "re": [r"(?<![\w.])Callable\(\s*[^\s)]"]},
	"WIRE-2": {"adr": "ADR-0001; ADR-0006 Decision 1", "pending": "", "scope": "src", "ext": "gd", "msg": "string signal API", "re": [r"\b(?:connect|disconnect|is_connected)\(\s*[&^]?[\x22\x27]", r"\bemit_signal\s*\("]},
	"WIRE-3": {"adr": "C2", "pending": "", "scope": "src", "ext": "gd", "msg": "lambda", "re": [r"(?<!\w)func\s*\("]},
	"WIRE-4": {"adr": "ADR-0001", "pending": "", "scope": "src", "ext": "gd", "msg": "bind or unbind"},
	"WIRE-5": {"adr": "ADR-0006 Decision 2", "pending": "ADR-0006", "scope": "src", "ext": "gd", "msg": "CONNECT_ flag", "named": ["battle_signal_contract.gd"]},
	"WIRE-6": {"adr": "ADR-0006 Decision 2", "pending": "ADR-0006", "scope": "src", "ext": "gd", "msg": "battle signal connected outside builder and wrapper", "exclude": ["battle_builder.gd", "battle_wrapper.gd"], "named": ["battle_signal_contract.gd"]},
	"WIRE-7": {"adr": "ADR-0006 Decision 2", "pending": "ADR-0006", "scope": "src", "ext": "tscn", "msg": "scene connection of a battle signal", "named": ["battle_signal_contract.gd"]},
	"WIRE-8": {"adr": "C3", "pending": "ADR-0006", "scope": "src", "ext": "gd", "msg": "listener not named on_<signal>", "named": ["battle_signal_contract.gd"]},
	"WIRE-9": {"adr": "ADR-0004; ADR-0006 Decision 7", "pending": "ADR-0006", "scope": "src", "ext": "gd", "msg": "listener body breaks a rule", "named": ["battle_signal_contract.gd"]},
	"WIRE-10": {"adr": "ADR-0006 Decision 4", "pending": "ADR-0006", "scope": "emitters", "ext": "gd", "msg": "signal parameter type", "named_classes": ["Flow", "Combat", "EnemyWave", "TowerSim", "HeroSim", "InputResolver", "InputAdapter"]},
	"WIRE-11": {"adr": "ADR-0002; ADR-0006 Validation 6", "pending": "ADR-0006", "scope": "src", "ext": "gd", "only": ["res://src/foundation/data/"], "msg": "signal in data", "re": [r"^signal\b"]},
	"WIRE-12": {"adr": "ADR-0006 Decision 4", "pending": "ADR-0006", "scope": "emitter_or_sim", "ext": "gd", "msg": "String id", "re": [r"\b(?:id|\w+_id)\s*:\s*String\b"]},
	"STATE-1": {"adr": "ADR-0001", "pending": "", "scope": "src", "ext": "gd", "msg": "static var", "re": [r"\bstatic\s+var\b"]},
	"STATE-2": {"adr": "ADR-0001", "pending": "", "scope": "sim", "ext": "gd", "msg": "member typed Battle", "re_member": [_MEMBER_PREFIX + r"var\s+\w+\s*(?::|:=)\s*Battle\b"]},
	"STATE-3": {"adr": "ADR-0001", "pending": "", "scope": "sim", "ext": "gd", "msg": "in-place reset", "re": [r"\bfunc\s+reset\s*\("]},
	"STATE-4": {"adr": "ADR-0009", "pending": "", "scope": "src", "ext": "gd", "exclude": ["res://src/core/combat/", "res://src/foundation/data/records/"], "msg": "health field written outside combat", "re": [r"\.(?:hp|max_hp|strength|ticks_left)\s*(?:=(?!=)|[+\-*/]=)"]},
	"STATE-5": {"adr": "ADR-0009 Decision 7", "pending": "", "scope": "src", "ext": "gd", "exclude": ["res://src/feature/enemy_wave/"], "msg": "add_enemy outside enemy_wave", "re": [r"\.add_enemy\s*\("]},
	"STATE-6": {"adr": "ADR-0009", "pending": "", "scope": "src", "ext": "gd", "msg": "roster view mutated", "re": [r"(?:\broster\(\)|\btargets\(\)|\btargets\.call\(\))\s*\.(?:append|erase|sort|sort_custom|clear|remove_at|insert|push_\w+|pop_\w+|resize|fill|reverse|shuffle|assign)\s*\("]},
	"STATE-7": {"adr": "ADR-0009; ADR-0005", "pending": "", "scope": "classes", "classes": ["Targetable", "Enemy", "Health", "Status", "PathTrack"], "ext": "gd", "msg": "combat piece holds a back reference", "named_classes": ["Targetable", "Enemy", "Health", "Status", "PathTrack"], "re_member": [_MEMBER_PREFIX + r"var\s+\w+\s*:\s*(?:ReadContext|EnemyWave|Combat|Battle|Callable|Targetable|Enemy|Object|Node|RefCounted)\b"]},
	"STATE-8": {"adr": "ADR-0009", "pending": "", "scope": "src", "ext": "gd", "msg": "collection changed while iterated"},
	"STATE-9": {"adr": "ADR-0007 Decision 11", "pending": "", "scope": "src", "ext": "gd", "msg": "packed array element write skips the setter"},
	"STATE-10": {"adr": "ADR-0002", "pending": "", "scope": "src", "ext": "gd", "only": ["catalogue.gd", "res://src/foundation/data/records/"], "named": ["catalogue.gd"], "msg": "Callable member in data", "re_member": [_MEMBER_PREFIX + r"var\s+\w+\s*(?::\s*Callable\b|:=\s*Callable\b)"]},
	"STAT-1": {"adr": "ADR-0005", "pending": "", "scope": "src", "ext": "gd", "msg": "stat key is not a StatKeys constant"},
	"TIME-1": {"adr": "ADR-0004", "pending": "", "scope": "src", "ext": "gd", "msg": "_physics_process", "re": [r"\bfunc\s+_physics_process\b"]},
	"TIME-2": {"adr": "ADR-0004", "pending": "", "scope": "src", "ext": "gd", "exclude": ["battle_wrapper.gd", "app_root.gd", "input_adapter.gd"], "msg": "_process outside wrapper, root and adapter", "re": [r"\bfunc\s+_process\b"]},
	"TIME-3": {"adr": "C4", "pending": "", "scope": "src", "ext": "gd", "exclude": ["dev_logs.gd", "gesture_log.gd"], "msg": "real-time source", "re": [r"(?<![\w.])Timer\b", r"\bcreate_timer\s*\(", r"\bawait\b", r"\bEngine\.time_scale\b", r"\bEngine\.get_frames_drawn\b", r"\bEngine\.get_process_frames\b", r"\bEngine\.get_physics_frames\b", r"(?<![\w.])Time\.\w*", r"\bOS\.get_ticks_\w*"]},
	"TIME-4": {"adr": "ADR-0003; ADR-0004", "pending": "", "scope": "src", "ext": "gd", "msg": "tree pause or low processor mode", "re": [r"\bget_tree\(\)\s*\.\s*paused\b", r"\blow_processor_mode\b"]},
	"TIME-5": {"adr": "ADR-0004", "pending": "", "scope": "sim", "ext": "gd", "msg": "float duration countdown", "re": [r"-=\s*(?:dt|delta|_dt)\b", r"\b([\w.]+)\s*=\s*\1\s*-\s*(?:dt|delta|_dt)\b"]},
	"MATH-1": {"adr": "ADR-0004", "pending": "", "scope": "sim", "ext": "gd", "skip_def": true, "msg": "global math call", "re": [r"(?<![\w.])(?:floor|ceil|abs|sign|round|sin|cos|tan|atan2|pow|exp|log|fmod|fposmod|lerp|move_toward|snapped)\s*\("]},
	"MATH-2": {"adr": "ADR-0004; ADR-0009", "pending": "", "scope": "sim", "ext": "gd", "msg": "Vector2 method", "re": [r"\.(?:distance_to|distance_squared_to|normalized|direction_to|angle_to|rotated|limit_length|dot|cross)\s*\("]},
	"MATH-3": {"adr": "ADR-0004", "pending": "", "scope": "sim", "ext": "gd", "skip_def": true, "msg": "engine random", "re": [r"\bRandomNumberGenerator\b", r"(?<![\w.])(?:randi_range|randf_range|randi|randf|randfn|randomize|seed)\s*\("]},
	"MATH-4": {"adr": "ADR-0004", "pending": "", "scope": "src_presentation", "ext": "gd", "msg": "rng use in presentation", "re": [r"\b(?:RandomNumberGenerator|SimRng|sim_rng)\b", r"(?<![\w.])(?:randi_range|randf_range|randi|randf|randfn|randomize|seed)\s*\("]},
	"MATH-6": {"adr": "ADR-0009", "pending": "", "scope": "sim", "ext": "gd", "msg": "Vector2 position member", "re_member": [_MEMBER_PREFIX + r"var\s+\w+\s*(?::\s*Vector2\b|:=\s*Vector2\s*\()"]},
	"INPUT-1": {"adr": "ADR-0003", "pending": "", "scope": "src", "ext": "gd", "exclude": ["res://src/foundation/input/input_adapter.gd"], "msg": "engine input callback outside adapter", "re": [r"\bfunc\s+(?:_input|_unhandled_input)\s*\("]},
	"INPUT-3": {"adr": "ADR-0003", "pending": "", "scope": "src", "ext": "gd", "exclude": ["input_adapter.gd"], "msg": "pointer polling", "re": [r"\bInput\.\w*(?:mouse|touch|screen|pointer)\w*\s*\("]},
	"INPUT-4": {"adr": "ADR-0003", "pending": "", "scope": "battle", "ext": "gd", "msg": "mouse event in battle code", "re": [r"\bInputEventMouse\w*"]},
	"INPUT-5": {"adr": "ADR-0003", "pending": "", "scope": "battle", "ext": "gd,tscn", "msg": "button in battle code", "re": [r"(?:^|\s)extends\s+(?:" + _BUTTONS + r")\b", r"\b(?:" + _BUTTONS + r")\.new\s*\("], "tscn_re": [r"\[node [^\]]*type=\x22(?:" + _BUTTONS + r")\x22"]},
	"INPUT-6": {"adr": "ADR-0003", "pending": "", "scope": "src", "ext": "gd", "msg": "device id literal", "re": [r"\.device\s*(?:==|!=)\s*-?\d", r"\d\s*(?:==|!=)\s*[\w.]*\.device\b"]},
	"INPUT-7": {"adr": "ADR-0003", "pending": "", "scope": "battle", "ext": "gd,tscn", "msg": "camera or canvas transform in battle", "re": [r"\bCamera2D\b", r"\bcanvas_transform\s*=(?!=)", r"\bset_canvas_transform\s*\("], "tscn_re": [r"\[node [^\]]*type=\x22Camera2D\x22"]},
	"INPUT-8": {"adr": "ADR-0003", "pending": "", "scope": "src", "ext": "gd", "exclude": ["input_adapter.gd"], "msg": "display metric outside adapter", "re": [r"\bDisplayServer\.(?:get_display_safe_area|screen_get_dpi|screen_get_scale|window_get_size|window_get_position)\b"]},
	"INPUT-9": {"adr": "ADR-0008 Validation 7", "pending": "ADR-0008", "scope": "src", "ext": "gd", "exclude": ["input_resolver.gd"], "msg": "InputResolver built outside its file", "re": [r"\bInputResolver\.new\s*\("]},
	"INPUT-10": {"adr": "ADR-0008 Validation 7", "pending": "ADR-0008", "scope": "src", "ext": "gd", "only": ["input_resolver.gd"], "named": ["input_resolver.gd"], "msg": "Vector2 method or Dictionary member", "re": [r"\.(?:distance_to|distance_squared_to|normalized|direction_to|angle_to|rotated|limit_length|dot|cross|length|length_squared|lerp|abs|floor|ceil|round|sign|clamp|project|reflect|slide|bounce|snapped)\s*\("], "re_member": [_MEMBER_PREFIX + r"var\s+\w+\s*(?::\s*Dictionary\b|:=\s*\{)"]},
	"REND-1": {"adr": "ADR-0011 Decision 7", "pending": "", "scope": "src_presentation", "also": ["battle_wrapper.tscn"], "ext": "gd,tscn", "msg": "material, light or particles", "re": [r"\bmaterial\s*=(?!=)", r"\b(?:ShaderMaterial|CanvasItemMaterial|Light2D|PointLight2D|CanvasModulate|GPUParticles2D|CPUParticles2D)\b"], "string_re": [r"\.gdshader"], "tscn_re": [r"^material\s*=", r"\b(?:ShaderMaterial|CanvasItemMaterial|Light2D|PointLight2D|CanvasModulate|GPUParticles2D|CPUParticles2D)\b", r"\.gdshader"]},
	"REND-2": {"adr": "ADR-0011 Decision 1", "pending": "", "scope": "src_presentation", "also": ["battle_wrapper.tscn"], "ext": "gd,tscn", "exclude": ["res://src/presentation/dev/"], "msg": "layering or drawing node"},
	"REND-3": {"adr": "ADR-0011 Decisions 4, 6", "pending": "", "scope": "src_presentation", "ext": "gd", "msg": "instantiate outside attach"},
	"ERR-1": {"adr": "C5", "pending": "", "scope": "src", "ext": "gd", "msg": "assert", "re": [r"(?<![\w.])assert\s*\("]},
	"ERR-3": {"adr": "ADR-0007 Decision 7", "pending": "", "scope": "src", "ext": "gd", "msg": "push_warning", "re": [r"\bpush_warning\s*\("]},
	"ERR-4": {"adr": "C5", "pending": "", "scope": "src", "ext": "gd", "skip_def": true, "msg": "free", "re": [r"(?<!\w)free\s*\("]},
	"ERR-5": {"adr": "ADR-0001", "pending": "", "scope": "src", "ext": "gd", "only": ["res://src/root/app_root.gd"], "named": ["res://src/root/app_root.gd"], "msg": "preload in app_root", "re": [r"\bpreload\s*\("]},
	"INIT-1": {"adr": "ADR-0009 V7", "pending": "", "scope": "src_tests", "ext": "gd", "msg": "_init does not call super"},
	"TEST-1": {"adr": "TR-input-014", "pending": "", "scope": "tests", "ext": "gd", "msg": "gdUnit4 signal assert", "re": [r"\b(?:assert_signal|monitor_signals)\s*\("]},
	"TEST-2": {"adr": "TR-data-012", "pending": "", "scope": "tests_unit", "ext": "gd", "msg": "file access or non-script load in a unit test", "re": [r"\b(?:FileAccess|DirAccess|ConfigFile|ResourceLoader)\b"]},
	"TEST-3": {"adr": "TR-enemy-014", "pending": "", "scope": "tests_unit", "ext": "gd", "msg": "scene in a unit test", "re": [r"\binstantiate\s*\(", r"\bscene_runner\s*\("], "string_re": [r"\.tscn"]},
	"TEST-4": {"adr": "ADR-0004 Decision 9", "pending": "", "scope": "tests", "ext": "gd", "msg": "baseline file written by a test"},
	"TEST-5": {"adr": "ADR-0007 Decision 3", "pending": "", "scope": "tests", "ext": "gd", "msg": "simulated input", "re": [r"\bsimulate_\w*"]},
	"TEST-6": {"adr": "coding-standards.md", "pending": "", "scope": "tests", "ext": "gd", "msg": "skip or unknown test parameter"},
	"PROJ-1": {"adr": "ADR-0001 V5", "pending": "", "scope": "project", "ext": "project", "msg": "autoload section"},
	"PROJ-2": {"adr": "ADR-0001 Decision 1", "pending": "", "scope": "project", "ext": "project", "named": ["res://src/root/app_root.tscn"], "msg": "main scene"},
	"PROJ-3": {"adr": "ADR-0003", "pending": "", "scope": "project", "ext": "project", "msg": "display or input key"},
	"PROJ-4": {"adr": "ADR-0004", "pending": "", "scope": "project", "ext": "project", "msg": "run settings"},
	"PROJ-5": {"adr": "ADR-0007 Decision 7", "pending": "", "scope": "project", "ext": "project", "msg": "gdunit4 report settings"},
	"PROJ-6": {"adr": "ADR-0002 Validation 10", "pending": "", "scope": "project", "ext": "project", "named": ["res://export_presets.cfg"], "msg": "include_filter"},
	"PROJ-7": {"adr": "ADR-0007 Decision 1", "pending": "", "scope": "project", "ext": "project", "named": ["res://export_presets.cfg"], "msg": "exclude_filter"},
}
