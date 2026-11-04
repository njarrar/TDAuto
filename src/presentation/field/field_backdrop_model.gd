class_name FieldBackdropModel extends RefCounted
## Field backdrop data (ADR-0011 Decisions 3, 5, 8): fill colour, grid, the baked path quads
## (twice: edge and body), slot visibility, danger pulse and leak pop. Redraws only on change.

var field_color: Color = Color.BLACK
var grid_lines: PackedVector2Array = PackedVector2Array()
var edge_quads: PackedVector2Array = PackedVector2Array()
var body_quads: PackedVector2Array = PackedVector2Array()
var slot_centres: PackedVector2Array = PackedVector2Array()
var slot_free: PackedByteArray = PackedByteArray()
var exit_pos: Vector2 = Vector2.ZERO
var exit_dir: Vector2 = Vector2.DOWN
var danger_on: bool = false
var danger_alpha: float = 0.0
var leak_pop: float = 0.0

var _flow: Flow = null
var _roster: Callable = Callable()
var _tower_sim: TowerSim = null
var _hero_sim: HeroSim = null
var _reduce_motion: bool = false
var _dev_error: Callable = Callable()
var _hue: float = 0.0
var _base: float = 0.0
var _path_len: float = 0.0
var _clock_ms: float = 0.0
var _hold_ms: float = 0.0
var _pop_ms: float = 0.0
var _last_lives: int = -1
var _last_value: float = -1.0
var _last_alpha: float = -1.0
var _first: bool = true


## Bakes the path and checks the look values. False on a bad look or a failed bake.
func attach(stage_record: StageRecord, flow: Flow, enemy_wave: EnemyWave, tower_sim: TowerSim,
		hero_sim: HeroSim, field_hue: float, base_value: float, grid_tilt_deg: int,
		reduce_motion: bool, dev_error: Callable) -> bool:
	if stage_record == null or flow == null or enemy_wave == null or tower_sim == null or hero_sim == null:
		return false
	if not StageLook.values_in_range(field_hue, base_value, grid_tilt_deg):
		return false
	edge_quads = PathOutline.bake(stage_record.path_points, stage_record.path_width)
	body_quads = PathOutline.bake(stage_record.path_points, stage_record.path_width - 4.0)
	if edge_quads.is_empty() or body_quads.is_empty():
		return false
	_flow = flow
	_roster = enemy_wave.roster
	_tower_sim = tower_sim
	_hero_sim = hero_sim
	_reduce_motion = reduce_motion
	_dev_error = dev_error
	_hue = field_hue
	_base = base_value
	var pts: PackedFloat64Array = stage_record.path_points
	@warning_ignore("integer_division")
	var n: int = pts.size() / 2
	for i: int in range(n - 1):
		var dx: float = pts[(i + 1) * 2] - pts[i * 2]
		var dy: float = pts[(i + 1) * 2 + 1] - pts[i * 2 + 1]
		_path_len += sqrt(dx * dx + dy * dy)
	exit_pos = Vector2(pts[(n - 1) * 2], pts[(n - 1) * 2 + 1])
	var ex: float = pts[(n - 1) * 2] - pts[(n - 2) * 2]
	var ey: float = pts[(n - 1) * 2 + 1] - pts[(n - 2) * 2 + 1]
	var el: float = sqrt(ex * ex + ey * ey)
	exit_dir = Vector2(ex / el, ey / el)
	_build_grid(grid_tilt_deg)
	var count: int = tower_sim.slot_count()
	slot_free.resize(count)
	slot_centres.resize(count)
	for i: int in range(count):
		slot_centres[i] = tower_sim.slot_position(i)
		slot_free[i] = 1
	return true


## Frame step 4. True only on a change (slot hidden, danger on, off or pulsing, value shift).
func refresh(view_ms: float) -> bool:
	if _flow == null:
		return false
	var step: float = view_ms if (is_finite(view_ms) and view_ms > 0.0) else 0.0
	_clock_ms += step
	var changed: bool = _first
	_first = false
	for i: int in range(slot_free.size()):
		var free: int = 1 if _tower_sim.slot_tower(i) == &"" else 0
		if free != slot_free[i]:
			slot_free[i] = free
			changed = true
	var near: bool = false
	var list: Array[Targetable] = _roster.call()
	for t: Targetable in list:
		if t.distance >= _path_len - ViewStyles.DANGER_ZONE:
			near = true
			break
	_hold_ms = ViewStyles.DANGER_HOLD_MS if near else maxf(0.0, _hold_ms - step)
	danger_on = _hold_ms > 0.0
	danger_alpha = 0.0
	if danger_on:
		danger_alpha = 1.0
		if not _reduce_motion:
			danger_alpha = 0.5 + 0.5 * sin(_clock_ms * TAU / ViewStyles.DANGER_PULSE_PERIOD_MS)
	if absf(danger_alpha - _last_alpha) > 0.0001:
		changed = true
	_last_alpha = danger_alpha
	var lives: int = _flow.lives()
	if _last_lives >= 0 and lives < _last_lives:
		_pop_ms = ViewStyles.LEAK_POP_MS
	_last_lives = lives
	if _pop_ms > 0.0:
		_pop_ms = maxf(0.0, _pop_ms - step)
		changed = true
	leak_pop = 0.0 if _reduce_motion else _pop_ms / ViewStyles.LEAK_POP_MS
	var value: float = _base
	if _hero_sim.burst_state() == HeroSim.BurstState.TELEGRAPHING:
		value = maxf(0.0, _base - ViewStyles.FIELD_DIP)
	if absf(value - _last_value) > 0.00001:
		_last_value = value
		field_color = Color.from_hsv(_hue / 360.0, 0.35, value)
		changed = true
	return changed


## Drops every reference.
func detach() -> void:
	_flow = null
	_roster = Callable()
	_tower_sim = null
	_hero_sim = null
	_dev_error = Callable()


func _build_grid(tilt_deg: int) -> void:
	grid_lines.clear()
	var a: float = deg_to_rad(float(tilt_deg))
	var c: float = cos(a)
	var s: float = sin(a)
	var cx: float = FieldBounds.WIDTH * 0.5
	var cy: float = FieldBounds.HEIGHT * 0.5
	var reach: float = 1200.0
	var k: float = -reach
	while k <= reach:
		# Line family 1: direction (c, s), offset k along the normal (-s, c).
		_clip_line(cx - s * k - c * reach, cy + c * k - s * reach, cx - s * k + c * reach, cy + c * k + s * reach)
		# Family 2: direction (-s, c).
		_clip_line(cx + c * k + s * reach, cy + s * k - c * reach, cx + c * k - s * reach, cy + s * k + c * reach)
		k += ViewStyles.GRID_STEP


func _clip_line(x0: float, y0: float, x1: float, y1: float) -> void:
	var t0: float = 0.0
	var t1: float = 1.0
	var dx: float = x1 - x0
	var dy: float = y1 - y0
	var p: Array[float] = [-dx, dx, -dy, dy]
	var q: Array[float] = [x0, FieldBounds.WIDTH - x0, y0, FieldBounds.HEIGHT - y0]
	for i: int in range(4):
		if absf(p[i]) < 0.0000001:
			if q[i] < 0.0:
				return
		else:
			var r: float = q[i] / p[i]
			if p[i] < 0.0:
				t0 = maxf(t0, r)
			else:
				t1 = minf(t1, r)
	if t0 < t1:
		grid_lines.append(Vector2(x0 + t0 * dx, y0 + t0 * dy))
		grid_lines.append(Vector2(x0 + t1 * dx, y0 + t1 * dy))
