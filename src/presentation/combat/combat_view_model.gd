class_name CombatViewModel extends RefCounted
## Combat visuals (ADR-0011 Decisions 2 to 4): damaged cores, slow drag lines, tracers, splash
## rings, flashes, death discs and burst spokes. The one model with connections: burst_started
## (P7), attack_fired (P8), damage_applied (P9). Handlers write into fixed pools with the view
## time and never read the accessor. Every duration runs on view_ms.

var core_n: int = 0
var core_pos: PackedVector2Array = PackedVector2Array()
var core_frac: PackedFloat32Array = PackedFloat32Array()
## Pairs of points for the slow drag lines (one draw_multiline).
var slow_points: PackedVector2Array = PackedVector2Array()
var tower_lines: PackedVector2Array = PackedVector2Array()
var hero_lines: PackedVector2Array = PackedVector2Array()
var spoke_lines: PackedVector2Array = PackedVector2Array()
var ring_centres: PackedVector2Array = PackedVector2Array()
var ring_radii: PackedFloat32Array = PackedFloat32Array()
## Active death discs, oldest first: centre and alpha.
var death_centres: PackedVector2Array = PackedVector2Array()
var death_alphas: PackedFloat32Array = PackedFloat32Array()
## Active flashes: centre, alpha and whether it is a hero flash.
var flash_centres: PackedVector2Array = PackedVector2Array()
var flash_alphas: PackedFloat32Array = PackedFloat32Array()

const _T_TOWER: int = 0
const _T_HERO: int = 1
const _T_RING: int = 2
const _T_SPOKE: int = 3

var _roster: Callable = Callable()
var _combat: Combat = null
var _accessor: StatAccessor = null
var _halted: Callable = Callable()
var _reduce_motion: bool = false
var _dev_error: Callable = Callable()
var _clock_ms: float = 0.0
var _had_content: bool = false

# flash pool (slots, keyed by spawn id)
var _f_used: PackedByteArray = PackedByteArray()
var _f_id: PackedInt32Array = PackedInt32Array()
var _f_pos: PackedVector2Array = PackedVector2Array()
var _f_alpha: PackedFloat32Array = PackedFloat32Array()
var _f_hero: PackedByteArray = PackedByteArray()
var _f_born: PackedFloat64Array = PackedFloat64Array()

# tracer ring buffer
var _t_head: int = 0
var _t_count: int = 0
var _t_from: PackedVector2Array = PackedVector2Array()
var _t_to: PackedVector2Array = PackedVector2Array()
var _t_kind: PackedInt32Array = PackedInt32Array()
var _t_radius: PackedFloat32Array = PackedFloat32Array()
var _t_born: PackedFloat64Array = PackedFloat64Array()

# death disc ring buffer
var _d_head: int = 0
var _d_count: int = 0
var _d_pos: PackedVector2Array = PackedVector2Array()
var _d_born: PackedFloat64Array = PackedFloat64Array()

var _clearance: bool = false
var _tail_ms: float = -1.0


## Reads EnemyWave.roster each refresh.
func attach(combat: Combat, enemy_wave: EnemyWave, accessor: StatAccessor, halted: Callable,
		visual_keys: VisualKeys, reduce_motion: bool, dev_error: Callable) -> bool:
	if enemy_wave == null or combat == null or accessor == null:
		return false
	_roster = enemy_wave.roster
	_combat = combat
	_accessor = accessor
	_halted = halted
	_reduce_motion = reduce_motion
	_dev_error = dev_error
	_f_used.resize(ViewStyles.FLASH_POOL)
	_f_id.resize(ViewStyles.FLASH_POOL)
	_f_pos.resize(ViewStyles.FLASH_POOL)
	_f_alpha.resize(ViewStyles.FLASH_POOL)
	_f_hero.resize(ViewStyles.FLASH_POOL)
	_f_born.resize(ViewStyles.FLASH_POOL)
	_t_from.resize(ViewStyles.TRACER_POOL)
	_t_to.resize(ViewStyles.TRACER_POOL)
	_t_kind.resize(ViewStyles.TRACER_POOL)
	_t_radius.resize(ViewStyles.TRACER_POOL)
	_t_born.resize(ViewStyles.TRACER_POOL)
	_d_pos.resize(ViewStyles.DEATH_POOL)
	_d_born.resize(ViewStyles.DEATH_POOL)
	core_pos.resize(ViewStyles.ENEMY_POOL)
	core_frac.resize(ViewStyles.ENEMY_POOL)
	return true


## Drops every reference. The wrapper disconnects the three listeners first.
func detach() -> void:
	_roster = Callable()
	_combat = null
	_accessor = null
	_halted = Callable()
	_dev_error = Callable()
	core_n = 0


## True from burst_started until 0.15 s after the BURST attack_fired.
func clearance_active() -> bool:
	return _clearance


## Live flash markers.
func flash_count() -> int:
	var n: int = 0
	for i: int in range(_f_used.size()):
		if _f_used[i] != 0:
			n += 1
	return n


## True when a live flash is keyed to this spawn id.
func has_flash(spawn_id: int) -> bool:
	return _flash_slot(spawn_id) >= 0


## True when the live flash for this spawn id is a hero flash.
func flash_is_hero(spawn_id: int) -> bool:
	var s: int = _flash_slot(spawn_id)
	return s >= 0 and _f_hero[s] != 0


## Live tracer segments.
func tracer_count() -> int:
	return _t_count


## Live death discs.
func death_count() -> int:
	return _d_count


## P7: the clearance window opens.
func _on_burst_started(_aim_point: Vector2, _telegraph_ticks: int) -> void:
	_clearance = true
	_tail_ms = -1.0


## P8: adds a tracer, a splash ring or burst spokes. Never reads the accessor.
func _on_attack_fired(source_kind: Combat.SourceKind, _source_id: StringName, origin: Vector2,
		impact: Vector2, radius: float) -> void:
	match source_kind:
		Combat.SourceKind.TOWER:
			_add_tracer(_T_TOWER, origin, impact, 0.0)
			if radius > 0.0 and not _clearance:
				_add_tracer(_T_RING, impact, impact, radius)
		Combat.SourceKind.HERO:
			_add_tracer(_T_HERO, origin, impact, 0.0)
		Combat.SourceKind.BURST:
			_add_tracer(_T_SPOKE, origin, impact, radius)
			_tail_ms = ViewStyles.CLEARANCE_TAIL_MS


## P9: a kill makes a death disc; a hit makes or refreshes a flash marker.
func _on_damage_applied(source_kind: Combat.SourceKind, _source_id: StringName, _applied: float,
		position: Vector2, killed: bool, spawn_id: int) -> void:
	if killed:
		_add_death(position)
		return
	var hero: bool = source_kind != Combat.SourceKind.TOWER
	if not hero and _clearance:
		return
	var alpha: float = ViewStyles.FLASH_ALPHA_HERO if hero else ViewStyles.FLASH_ALPHA_TOWER
	_add_flash(spawn_id, position, alpha, hero)


## Frame step 4. Returns true when the drawer must redraw.
func refresh(view_ms: float) -> bool:
	if not _roster.is_valid():
		return false
	var step: float = view_ms if (is_finite(view_ms) and view_ms > 0.0) else 0.0
	_clock_ms += step
	if _clearance and _tail_ms >= 0.0:
		_tail_ms -= step
		if _tail_ms <= 0.0:
			_clearance = false
			_tail_ms = -1.0
	_expire()
	var list: Array[Targetable] = _roster.call()
	if list.size() > core_pos.size():
		core_pos.resize(list.size())
		core_frac.resize(list.size())
	core_n = 0
	slow_points.clear()
	for t: Targetable in list:
		var s: int = _flash_slot(t.spawn_id)
		if s >= 0:
			_f_pos[s] = t.view_position()
		if _combat.is_dead(t):
			continue
		if not (t is Enemy):
			continue
		var max_hp: float = _combat.max_hp_of(t)
		if max_hp <= 0.0:
			continue
		var p: Vector2 = t.view_position()
		core_pos[core_n] = p
		core_frac[core_n] = clampf(_combat.hp_left(t) / max_hp, 0.0, 1.0)
		core_n += 1
		if _combat.speed_factor(t) < 1.0:
			for k: int in range(3):
				var dx: float = float(k - 1) * 6.0
				slow_points.append(Vector2(p.x + dx, p.y + 20.0))
				slow_points.append(Vector2(p.x + dx, p.y + 28.0))
	_rebuild_outputs()
	var content: bool = core_n > 0 or _t_count > 0 or _d_count > 0 or flash_centres.size() > 0
	var changed: bool = content or _had_content
	_had_content = content
	return changed


func _flash_slot(spawn_id: int) -> int:
	for i: int in range(_f_used.size()):
		if _f_used[i] != 0 and _f_id[i] == spawn_id:
			return i
	return -1


func _add_flash(spawn_id: int, pos: Vector2, alpha: float, hero: bool) -> void:
	var s: int = _flash_slot(spawn_id)
	if s >= 0:
		_f_pos[s] = pos
		_f_alpha[s] = maxf(_f_alpha[s], alpha)
		_f_born[s] = _clock_ms
		if hero:
			_f_hero[s] = 1
		return
	for i: int in range(_f_used.size()):
		if _f_used[i] == 0:
			_set_flash(i, spawn_id, pos, alpha, hero)
			return
	# Full: oldest tower flash goes first; a hero flash may then take the oldest hero flash.
	var victim: int = _oldest_flash(false)
	if victim < 0 and hero:
		victim = _oldest_flash(true)
	if victim >= 0:
		_set_flash(victim, spawn_id, pos, alpha, hero)


func _oldest_flash(hero: bool) -> int:
	var best: int = -1
	for i: int in range(_f_used.size()):
		if _f_used[i] == 0 or (_f_hero[i] != 0) != hero:
			continue
		if best < 0 or _f_born[i] < _f_born[best]:
			best = i
	return best


func _set_flash(i: int, spawn_id: int, pos: Vector2, alpha: float, hero: bool) -> void:
	_f_used[i] = 1
	_f_id[i] = spawn_id
	_f_pos[i] = pos
	_f_alpha[i] = alpha
	_f_hero[i] = 1 if hero else 0
	_f_born[i] = _clock_ms


func _add_tracer(kind: int, from: Vector2, to: Vector2, radius: float) -> void:
	var cap: int = _t_from.size()
	if cap == 0:
		return
	if _t_count == cap:
		_t_head = (_t_head + 1) % cap
		_t_count -= 1
	var i: int = (_t_head + _t_count) % cap
	_t_from[i] = from
	_t_to[i] = to
	_t_kind[i] = kind
	_t_radius[i] = radius
	_t_born[i] = _clock_ms
	_t_count += 1


func _add_death(pos: Vector2) -> void:
	var cap: int = _d_pos.size()
	if cap == 0:
		return
	if _d_count == cap:
		_d_head = (_d_head + 1) % cap
		_d_count -= 1
	var i: int = (_d_head + _d_count) % cap
	_d_pos[i] = pos
	_d_born[i] = _clock_ms
	_d_count += 1


func _expire() -> void:
	var cap: int = _t_from.size()
	while _t_count > 0 and _clock_ms - _t_born[_t_head] >= ViewStyles.TRACER_MS:
		_t_head = (_t_head + 1) % cap
		_t_count -= 1
	var dcap: int = _d_pos.size()
	while _d_count > 0 and _clock_ms - _d_born[_d_head] >= ViewStyles.DEATH_MS:
		_d_head = (_d_head + 1) % dcap
		_d_count -= 1
	for i: int in range(_f_used.size()):
		if _f_used[i] != 0 and _clock_ms - _f_born[i] >= ViewStyles.FLASH_MS:
			_f_used[i] = 0


func _rebuild_outputs() -> void:
	tower_lines.clear()
	hero_lines.clear()
	spoke_lines.clear()
	ring_centres.clear()
	ring_radii.clear()
	var cap: int = _t_from.size()
	for n: int in range(_t_count):
		var i: int = (_t_head + n) % cap
		match _t_kind[i]:
			_T_TOWER:
				tower_lines.append(_t_from[i])
				tower_lines.append(_t_to[i])
			_T_HERO:
				hero_lines.append(_t_from[i])
				hero_lines.append(_t_to[i])
			_T_SPOKE:
				spoke_lines.append(_t_from[i])
				spoke_lines.append(_t_to[i])
			_T_RING:
				ring_centres.append(_t_to[i])
				ring_radii.append(_t_radius[i])
	death_centres.clear()
	death_alphas.clear()
	var dcap: int = _d_pos.size()
	for n: int in range(_d_count):
		var i: int = (_d_head + n) % dcap
		death_centres.append(_d_pos[i])
		death_alphas.append(clampf(1.0 - (_clock_ms - _d_born[i]) / ViewStyles.DEATH_MS, 0.0, 1.0))
	flash_centres.clear()
	flash_alphas.clear()
	for i: int in range(_f_used.size()):
		if _f_used[i] == 0:
			continue
		flash_centres.append(_f_pos[i])
		var fade: float = 1.0
		if not _reduce_motion:
			fade = clampf(1.0 - (_clock_ms - _f_born[i]) / ViewStyles.FLASH_MS, 0.0, 1.0)
		flash_alphas.append(_f_alpha[i] * fade)
