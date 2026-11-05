# PROTOTYPE - NOT FOR PRODUCTION. ADR-0011 V1 to V5.
extends RefCounted
## Shared buffers every drawer reads. main.gd fills them once per frame (the
## step 4 stand-in). Positions are deterministic from the frame number.

const PathBake := preload("res://path_bake.gd")

const ENEMY_COUNT := 48
const FLASH_COUNT := 16
const TRACER_COUNT := 64
const DEATH_COUNT := 48
const TEXT_SIZES: PackedInt32Array = [21, 24, 36]
const PATH_POINTS: PackedFloat64Array = [-40.0, 210.0, 430.0, 210.0, 430.0, 400.0, 110.0, 400.0, 110.0, 570.0, 270.0, 570.0, 270.0, 980.0]
const SLOTS: PackedVector2Array = [Vector2(270, 305), Vector2(190, 485), Vector2(350, 485), Vector2(170, 700), Vector2(370, 700)]
const PATH_WIDTH := 72.0
const ENEMY_RADIUS: PackedFloat32Array = [8.0, 11.0, 15.0]
const ENEMY_KEYS: Array[StringName] = [&"enemy_fast", &"enemy_normal", &"enemy_heavy"]

# Flags the keys in main.gd change.
var antialiased: bool = false
var line_bias: float = 1.0
var interleaved: bool = false
var tri_array: bool = false
var one_text_size: bool = false
var flash_on_material: bool = false

# Static geometry, built once.
var path_edge: PackedVector2Array = []
var path_body: PackedVector2Array = []
var grid_lines: PackedVector2Array = []
var path_len: float = 0.0
var glow_tex: GradientTexture2D

# Per-frame buffers.
var enemy_pos: PackedVector2Array = []
var enemy_style: PackedInt32Array = []
var enemy_hp: PackedFloat32Array = []
var slow_lines: PackedVector2Array = []
var flash_pos: PackedVector2Array = []
var flash_alpha: PackedFloat32Array = []
var tracer_lines: PackedVector2Array = []
var tracer_colors: PackedColorArray = []
var death_pos: PackedVector2Array = []
var death_alpha: PackedFloat32Array = []
var tower_cool: PackedFloat32Array = []
var hero_pos: Vector2 = Vector2(270, 640)
var aim_pos: Vector2 = Vector2(270, 500)
var gold: int = 120
var max_hp_reads: int = 0

var _pts: PackedVector2Array = []
var _cum: PackedFloat32Array = []
var _stats: Dictionary = {&"enemy_fast": 60, &"enemy_normal": 125, &"enemy_heavy": 750}


func _init() -> void:
	path_edge = PathBake.bake(PATH_POINTS, PATH_WIDTH)
	path_body = PathBake.bake(PATH_POINTS, PATH_WIDTH - 4.0)
	for i in PATH_POINTS.size() / 2:
		_pts.append(Vector2(PATH_POINTS[2 * i], PATH_POINTS[2 * i + 1]))
	_cum.append(0.0)
	for i in _pts.size() - 1:
		path_len += _pts[i].distance_to(_pts[i + 1])
		_cum.append(path_len)
	var x: float = 0.0
	while x <= 540.0:
		grid_lines.append(Vector2(x, 0.0))
		grid_lines.append(Vector2(x, 960.0))
		x += 60.0
	var y: float = 0.0
	while y <= 960.0:
		grid_lines.append(Vector2(0.0, y))
		grid_lines.append(Vector2(540.0, y))
		y += 60.0
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.9, 0.55, 0.85), Color(1.0, 0.9, 0.55, 0.0)])
	glow_tex = GradientTexture2D.new()
	glow_tex.gradient = g
	glow_tex.width = 128
	glow_tex.height = 128
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	enemy_pos.resize(ENEMY_COUNT)
	enemy_style.resize(ENEMY_COUNT)
	enemy_hp.resize(ENEMY_COUNT)
	flash_pos.resize(FLASH_COUNT)
	flash_alpha.resize(FLASH_COUNT)
	tracer_lines.resize(TRACER_COUNT * 2)
	tracer_colors.resize(TRACER_COUNT)
	death_pos.resize(DEATH_COUNT)
	death_alpha.resize(DEATH_COUNT)
	tower_cool.resize(SLOTS.size())


## Point at distance d along the path.
func point_at(d: float) -> Vector2:
	for i in _pts.size() - 1:
		if d <= _cum[i + 1]:
			var seg: float = _cum[i + 1] - _cum[i]
			return _pts[i].lerp(_pts[i + 1], (d - _cum[i]) / maxf(seg, 0.001))
	return _pts[_pts.size() - 1]


## Stand-in for a stat accessor read through a read context.
func read_max_hp(def_id: StringName) -> int:
	max_hp_reads += 1
	return int(_stats.get(def_id, 0))


## Fills every per-frame buffer for frame f (the step 4 stand-in).
func update(f: int) -> void:
	max_hp_reads = 0
	var spacing: float = path_len / float(ENEMY_COUNT)
	slow_lines.clear()
	for i in ENEMY_COUNT:
		var d: float = fmod(float(f) * 1.5 + float(i) * spacing, path_len)
		enemy_pos[i] = point_at(d)
		enemy_style[i] = i % 3
		var max_hp: int = read_max_hp(ENEMY_KEYS[i % 3])
		var left: float = float(max_hp) * (0.3 + 0.7 * float((i * 7 + f / 10) % 10) / 10.0)
		enemy_hp[i] = left / float(maxi(max_hp, 1))
		if i % 4 == 0:
			var back: Vector2 = point_at(maxf(d - 24.0, 0.0))
			slow_lines.append(back)
			slow_lines.append(enemy_pos[i])
	for i in FLASH_COUNT:
		flash_pos[i] = enemy_pos[i * 3]
		flash_alpha[i] = 0.6 if i % 2 == 0 else 1.0
	for i in TRACER_COUNT:
		var from: Vector2 = SLOTS[i % SLOTS.size()] if i < 48 else hero_pos
		tracer_lines[2 * i] = from
		tracer_lines[2 * i + 1] = enemy_pos[(i + f / 6) % ENEMY_COUNT]
		tracer_colors[i] = Color(1.0, 1.0, 1.0, 0.7) if i < 48 else Color(1.0, 0.85, 0.4, 0.9)
	for i in DEATH_COUNT:
		death_pos[i] = Vector2(float((i * 97) % 520) + 10.0, float((i * 151) % 900) + 40.0)
		death_alpha[i] = 0.2 + 0.6 * float((i + f / 4) % 8) / 8.0
	for i in SLOTS.size():
		tower_cool[i] = fmod(float(f) / 90.0 + float(i) * 0.2, 1.0)
	hero_pos = Vector2(270.0 + 30.0 * sin(float(f) / 50.0), 640.0)
	aim_pos = hero_pos + Vector2(60.0 * cos(float(f) / 40.0), -120.0)
	gold = 120 + (f / 30) % 900


## Dashed circle as line segments: on and off are arc lengths in units.
static func dashed_circle(center: Vector2, radius: float, on: float, off: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	var circ: float = TAU * radius
	var s: float = 0.0
	while s < circ:
		var a0: float = s / radius
		var a1: float = minf(s + on, circ) / radius
		out.append(center + Vector2(cos(a0), sin(a0)) * radius)
		out.append(center + Vector2(cos(a1), sin(a1)) * radius)
		s += on + off
	return out
