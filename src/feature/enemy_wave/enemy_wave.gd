class_name EnemyWave extends RefCounted
## Sole owner of every enemy (ADR-0009 Decision 7). Runs the wave schedule,
## movement, leaks and reaping. Holds Combat (down) and nothing holds it back.

enum WaveState { WAITING, ACTIVE, FINISHED }

## An enemy leaked off the end of the path.
signal enemy_leaked(lives_cost: int)
## A dead enemy was reaped.
signal enemy_killed(bounty: int)
## A non-last wave cleared.
signal wave_cleared(intermission_duration: float)
## The last wave cleared.
signal waves_completed()

var _stage: StageRecord
var _waves: Array[WaveRecord]
var _accessor: StatAccessor
var _combat: Combat
var _dt: float
var _field_w: float
var _field_h: float
var _halted: Callable
var _fatal: Callable
var _dev_error: Callable
var _to_ticks: Callable

var _path: PathTrack = null
var _roster: Array[Targetable] = []
var _targets: Array[Targetable] = []
var _contexts: Dictionary[int, ReadContext] = {}
var _roster_count: int = 0
var _targets_count: int = 0
var _next_spawn_id: int = 0
var _wave_state: WaveState = WaveState.WAITING
var _wave_index: int = 0
var _wave_tick: int = 0
## Next member index to spawn, per group of the current wave.
var _group_next: Array[int] = []
var _got_through: Dictionary = {}


func _init(stage: StageRecord, waves: Array[WaveRecord], accessor: StatAccessor, combat: Combat,
		dt: float, field_w: float, field_h: float,
		halted: Callable, fatal: Callable, dev_error: Callable, to_ticks: Callable) -> void:
	_stage = stage
	_waves = waves
	_accessor = accessor
	_combat = combat
	_dt = dt
	_field_w = field_w
	_field_h = field_h
	_halted = halted
	_fatal = fatal
	_dev_error = dev_error
	_to_ticks = to_ticks
	_path = PathTrack.make(stage.path_points)
	if _path == null:
		_fatal.call("enemy_wave: bad path_points for %s" % String(stage.id))


## Starts the next wave. Ignored with a development error while a wave is
## active, after the last wave, or when there is no wave left.
func start_next_wave() -> void:
	if _wave_state != WaveState.WAITING or _wave_index >= _waves.size():
		_dev_error.call("enemy_wave.start_next_wave: no wave can start (state %d, index %d)" % [
				int(_wave_state), _wave_index])
		return
	var wave: WaveRecord = _waves[_wave_index]
	_wave_index += 1
	_wave_state = WaveState.ACTIVE
	_wave_tick = 0
	_group_next.clear()
	for _g: WaveGroup in wave.groups:
		_group_next.append(0)


## The one way an enemy joins the roster. Callers: EnemyWave's spawn step, and
## tests. Returns false if a read halted or attach failed; nothing persists then.
func add_enemy(def_id: StringName, start_distance: float) -> bool:
	var id: int = _next_spawn_id
	_next_spawn_id += 1
	var e: Enemy = Enemy.new(id, def_id)
	var ctx: ReadContext = ReadContext.make(def_id, 0, e)
	var max_hp: float = _accessor.stat_float(ctx, StatKeys.MAX_HP)
	if bool(_halted.call()):
		return false
	if not _combat.attach(e, max_hp):
		_fatal.call("enemy_wave.add_enemy: attach failed for %s" % String(def_id))
		return false
	e.distance = start_distance
	_path.place(e)
	_roster.append(e)
	_contexts[id] = ctx
	if _in_field(e):
		_targets.append(e)
	_roster_count = _roster.size()
	_targets_count = _targets.size()
	return true


## Spawn, move, rebuild targets, leak. Then the wave tick rises.
func advance() -> void:
	_check_ownership()
	if _path == null or bool(_halted.call()):
		return
	if _wave_state == WaveState.ACTIVE:
		if not _spawn_due():
			return
	if not _move_all():
		return
	_rebuild_targets()
	if not _leak_loop():
		return
	if _wave_state == WaveState.ACTIVE:
		_wave_tick += 1


## Reap dead enemies, then the clear check while a wave is active.
func reap() -> void:
	_check_ownership()
	if _path == null or bool(_halted.call()):
		return
	var i: int = 0
	while i < _roster.size():
		var e: Targetable = _roster[i]
		if not _combat.is_dead(e):
			i += 1
			continue
		var bounty: int = _accessor.stat_int(_contexts[e.spawn_id], StatKeys.BOUNTY)
		if bool(_halted.call()):
			return
		_remove_at(i, e)
		enemy_killed.emit(bounty)
		if bool(_halted.call()):
			return
	if _wave_state != WaveState.ACTIVE or not _roster.is_empty() or not _schedule_exhausted():
		return
	if _wave_index >= _waves.size():
		_wave_state = WaveState.FINISHED
		waves_completed.emit()
	else:
		_wave_state = WaveState.WAITING
		wave_cleared.emit(_waves[_wave_index - 1].intermission_duration)


## Every enemy not yet removed, in spawn_id order. Internal buffer: read-only,
## never kept past the reader's slot.
func roster() -> Array[Targetable]:
	return _roster


## The roster entries whose centre is inside the field. Internal buffer:
## read-only, never kept past the reader's slot.
func targets() -> Array[Targetable]:
	return _targets


## 1-based index of the last wave started; 0 before the first start.
func wave_index() -> int:
	return _wave_index


## Leak counts per enemy def id, kept for the whole battle.
func got_through_by_type() -> Dictionary:
	return _got_through.duplicate()


func wave_state() -> WaveState:
	return _wave_state


## Ticks since the current wave started.
func wave_tick() -> int:
	return _wave_tick


func _in_field(e: Targetable) -> bool:
	return e.pos_x >= 0.0 and e.pos_x <= _field_w and e.pos_y >= 0.0 and e.pos_y <= _field_h


func _check_ownership() -> void:
	if _roster.size() != _roster_count or _targets.size() != _targets_count:
		_dev_error.call("enemy_wave: roster or targets changed by a caller (roster %d, expected %d; targets %d, expected %d)" % [
				_roster.size(), _roster_count, _targets.size(), _targets_count])
		_roster_count = _roster.size()
		_targets_count = _targets.size()


func _schedule_exhausted() -> bool:
	if _wave_index < 1:
		return true
	var groups: Array[WaveGroup] = _waves[_wave_index - 1].groups
	var g: int = 0
	while g < groups.size():
		if _group_next[g] < groups[g].count:
			return false
		g += 1
	return true


## Spawns every member due at `_wave_tick`. Returns false if a spawn failed.
func _spawn_due() -> bool:
	var groups: Array[WaveGroup] = _waves[_wave_index - 1].groups
	var g: int = 0
	while g < groups.size():
		var group: WaveGroup = groups[g]
		while _group_next[g] < group.count:
			var due: int = int(_to_ticks.call(group.start_delay + float(_group_next[g]) * group.spawn_interval))
			if due > _wave_tick:
				break
			if not add_enemy(group.enemy_id, 0.0):
				return false
			_group_next[g] += 1
		g += 1
	return true


## Moves every live enemy. Returns false if a read halted.
func _move_all() -> bool:
	var end: float = _path.path_length()
	for t: Targetable in _roster:
		if _combat.is_dead(t):
			continue
		var speed: float = _accessor.stat_float(_contexts[t.spawn_id], StatKeys.MOVE_SPEED)
		if bool(_halted.call()):
			return false
		t.distance = minf(t.distance + speed * _combat.speed_factor(t) * _dt, end)
		_path.place(t as Enemy)
	return true


func _rebuild_targets() -> void:
	_targets.clear()
	for t: Targetable in _roster:
		if _in_field(t):
			_targets.append(t)
	_targets_count = _targets.size()


## Leaks every enemy at the end of the path. Returns false if halted.
func _leak_loop() -> bool:
	var end: float = _path.path_length()
	var i: int = 0
	while i < _roster.size():
		var e: Targetable = _roster[i]
		if e.distance < end:
			i += 1
			continue
		var cost: int = _accessor.stat_int(_contexts[e.spawn_id], StatKeys.LIVES_COST)
		if bool(_halted.call()):
			return false
		var def_id: StringName = (e as Enemy).def_id
		_got_through[def_id] = int(_got_through.get(def_id, 0)) + 1
		_remove_at(i, e)
		enemy_leaked.emit(cost)
		if bool(_halted.call()):
			return false
	return true


## Commits one removal from the roster, targets and contexts. The caller does
## not advance its index afterwards.
func _remove_at(i: int, e: Targetable) -> void:
	e.removed = true
	_roster.remove_at(i)
	_targets.erase(e)
	_contexts.erase(e.spawn_id)
	_roster_count = _roster.size()
	_targets_count = _targets.size()
