class_name HeroViewModel extends RefCounted
## Hero draw buffers (ADR-0011 Decisions 2 to 4). Polls HeroSim and HeroInput. The leash, reach
## and kill-preview rings need accessor, targets and combat reads; they are added as optional
## trailing attach arguments (the wrapper signature has none). Without them those rings are off.

const KILL_MARK_CAP: int = 48

var hero_pos: Vector2 = Vector2.ZERO
var show_grab: bool = false
var show_leash: bool = false
var leash_radius: float = 0.0
var show_ghost: bool = false
var ghost_pos: Vector2 = Vector2.ZERO
var pin_pos: Vector2 = Vector2.ZERO
var show_reach: bool = false
var reach_radius: float = 0.0
var show_preview: bool = false
var aim_pos: Vector2 = Vector2.ZERO
var cancelling: bool = false
var burst_radius: float = 0.0
var kill_marks: PackedVector2Array = PackedVector2Array()
var telegraph_ring: bool = false
var telegraph_pos: Vector2 = Vector2.ZERO
var glow_centres: PackedVector2Array = PackedVector2Array()
var glow_alphas: PackedFloat32Array = PackedFloat32Array()
var hero_key: StringName = &""

var _hero_sim: HeroSim = null
var _hero_input: HeroInput = null
var _visual_keys: VisualKeys = null
var _reduce_motion: bool = false
var _dev_error: Callable = Callable()
var _accessor: StatAccessor = null
var _targets: Callable = Callable()
var _combat: Combat = null
var _halted: Callable = Callable()
var _hero_ctx: ReadContext = null
var _burst_ctx: ReadContext = null
var _clock_ms: float = 0.0
var _prev_burst: HeroSim.BurstState = HeroSim.BurstState.READY
var _g_head: int = 0
var _g_count: int = 0
var _g_pos: PackedVector2Array = PackedVector2Array()
var _g_born: PackedFloat64Array = PackedFloat64Array()


## Optional trailing arguments enable the leash ring, reach ring and kill preview.
func attach(hero_sim: HeroSim, hero_input: HeroInput, visual_keys: VisualKeys, reduce_motion: bool,
		dev_error: Callable, accessor: StatAccessor = null, enemy_wave: EnemyWave = null,
		combat: Combat = null, halted: Callable = Callable()) -> bool:
	if hero_sim == null or hero_input == null or visual_keys == null:
		return false
	_hero_sim = hero_sim
	_hero_input = hero_input
	_visual_keys = visual_keys
	_reduce_motion = reduce_motion
	_dev_error = dev_error
	_accessor = accessor
	_targets = enemy_wave.targets if enemy_wave != null else Callable()
	_combat = combat
	_halted = halted
	_hero_ctx = ReadContext.make(hero_sim.hero_id(), 0)
	_burst_ctx = ReadContext.make(hero_sim.burst_id(), 0)
	_g_pos.resize(ViewStyles.GLOW_POOL)
	_g_born.resize(ViewStyles.GLOW_POOL)
	hero_key = visual_keys.hero()
	return true


## Frame step 4. Always true while attached (the hero moves and aims every frame).
func refresh(view_ms: float) -> bool:
	if _hero_sim == null:
		return false
	if is_finite(view_ms) and view_ms > 0.0:
		_clock_ms += view_ms
	hero_pos = _hero_sim.position()
	pin_pos = _hero_sim.pin_target()
	var pin: HeroSim.PinState = _hero_sim.pin_state()
	show_grab = pin == HeroSim.PinState.UNPINNED
	show_leash = pin != HeroSim.PinState.UNPINNED
	var aim: HeroInput.AimState = _hero_input.aim_state()
	show_ghost = aim == HeroInput.AimState.PINNING
	ghost_pos = _hero_input.ghost_point()
	show_reach = aim == HeroInput.AimState.CANCELLING or aim == HeroInput.AimState.LIVE
	show_preview = aim == HeroInput.AimState.LIVE
	cancelling = aim == HeroInput.AimState.CANCELLING
	aim_pos = _hero_input.aim_point()
	kill_marks.clear()
	if _accessor != null:
		if show_leash:
			leash_radius = _accessor.stat_float(_hero_ctx, StatKeys.LEASH_RADIUS)
			if _halted_now():
				return false
		if show_reach:
			reach_radius = _accessor.stat_float(_burst_ctx, StatKeys.REACH)
			burst_radius = _accessor.stat_float(_burst_ctx, StatKeys.RADIUS)
			if _halted_now():
				return false
			if show_preview:
				_find_kills()
	var state: HeroSim.BurstState = _hero_sim.burst_state()
	telegraph_ring = state == HeroSim.BurstState.TELEGRAPHING
	telegraph_pos = _hero_input.last_aim_fired()
	if _prev_burst == HeroSim.BurstState.TELEGRAPHING and state != HeroSim.BurstState.TELEGRAPHING \
			and not _reduce_motion:
		_add_glow(telegraph_pos)
	_prev_burst = state
	_expire_glow()
	return true


## Drops every reference.
func detach() -> void:
	_hero_sim = null
	_hero_input = null
	_visual_keys = null
	_dev_error = Callable()
	_accessor = null
	_targets = Callable()
	_combat = null
	_halted = Callable()


func _halted_now() -> bool:
	return _halted.is_valid() and bool(_halted.call())


func _find_kills() -> void:
	if _combat == null or not _targets.is_valid():
		return
	var damage: float = _accessor.stat_float(_burst_ctx, StatKeys.DAMAGE)
	if _halted_now():
		return
	var list: Array[Targetable] = _targets.call()
	var r2: float = burst_radius * burst_radius
	for t: Targetable in list:
		if kill_marks.size() >= KILL_MARK_CAP:
			break
		var dx: float = t.pos_x - aim_pos.x
		var dy: float = t.pos_y - aim_pos.y
		if dx * dx + dy * dy <= r2 and not _combat.is_dead(t) and _combat.hp_left(t) <= damage:
			kill_marks.append(t.view_position())


func _add_glow(pos: Vector2) -> void:
	var cap: int = _g_pos.size()
	if _g_count == cap:
		_g_head = (_g_head + 1) % cap
		_g_count -= 1
	var i: int = (_g_head + _g_count) % cap
	_g_pos[i] = pos
	_g_born[i] = _clock_ms
	_g_count += 1


func _expire_glow() -> void:
	var cap: int = _g_pos.size()
	while _g_count > 0 and _clock_ms - _g_born[_g_head] >= ViewStyles.GLOW_MS:
		_g_head = (_g_head + 1) % cap
		_g_count -= 1
	glow_centres.clear()
	glow_alphas.clear()
	for n: int in range(_g_count):
		var i: int = (_g_head + n) % cap
		glow_centres.append(_g_pos[i])
		glow_alphas.append(clampf(1.0 - (_clock_ms - _g_born[i]) / ViewStyles.GLOW_MS, 0.0, 1.0))
