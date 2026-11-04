class_name EnemyViewModel extends RefCounted
## Enemy draw buffers (ADR-0011 Decisions 2 and 4). Polls the roster in refresh and keeps
## copies only: positions, kinds, spawn ids, colours. Sorted heavy, normal, fast, then spawn_id.
## The roster Callable is EnemyWave.roster; the model never mutates or keeps the array.

var count: int = 0
var positions: PackedVector2Array = PackedVector2Array()
var kinds: PackedInt32Array = PackedInt32Array()
var spawn_ids: PackedInt32Array = PackedInt32Array()
var colors: PackedColorArray = PackedColorArray()

var _roster: Callable = Callable()
var _visual_keys: VisualKeys = null
var _reduce_motion: bool = false
var _dev_error: Callable = Callable()
var _clock_ms: float = 0.0
var _grow_reported: bool = false
var _had_content: bool = false


## Reads EnemyWave.roster each refresh.
func attach(enemy_wave: EnemyWave, visual_keys: VisualKeys, reduce_motion: bool, dev_error: Callable) -> bool:
	if enemy_wave == null or visual_keys == null:
		return false
	_roster = enemy_wave.roster
	_visual_keys = visual_keys
	_reduce_motion = reduce_motion
	_dev_error = dev_error
	_resize(ViewStyles.ENEMY_POOL)
	return true


## Frame step 4. Returns true when the drawer must redraw.
func refresh(view_ms: float) -> bool:
	if not _roster.is_valid():
		return false
	if is_finite(view_ms) and view_ms > 0.0:
		_clock_ms += view_ms
	var list: Array[Targetable] = _roster.call()
	if list.size() > positions.size():
		_resize(list.size())
		if not _grow_reported:
			_grow_reported = true
			if _dev_error.is_valid():
				_dev_error.call("EnemyViewModel: roster of %d exceeds the pool of %d" % [list.size(), ViewStyles.ENEMY_POOL])
	count = 0
	for t: Targetable in list:
		var enemy: Enemy = t as Enemy
		if enemy == null:
			continue
		var key: StringName = _visual_keys.enemy(enemy.def_id)
		var kind: int = ViewStyles.kind_of(key)
		var sid: int = enemy.spawn_id
		var j: int = count
		while j > 0 and _before(kind, sid, kinds[j - 1], spawn_ids[j - 1]):
			positions[j] = positions[j - 1]
			kinds[j] = kinds[j - 1]
			spawn_ids[j] = spawn_ids[j - 1]
			colors[j] = colors[j - 1]
			j -= 1
		var p: Vector2 = enemy.view_position()
		if not _reduce_motion:
			p.y += sin(_clock_ms * 0.008 + float(sid)) * ViewStyles.BOB_AMPLITUDE
		positions[j] = p
		kinds[j] = kind
		spawn_ids[j] = sid
		colors[j] = ViewStyles.color_of(key)
		count += 1
	var changed: bool = count > 0 or _had_content
	_had_content = count > 0
	return changed


## Drops every reference.
func detach() -> void:
	_roster = Callable()
	_visual_keys = null
	_dev_error = Callable()
	count = 0


func _before(kind: int, sid: int, other_kind: int, other_sid: int) -> bool:
	if kind != other_kind:
		return kind < other_kind
	return sid < other_sid


func _resize(n: int) -> void:
	positions.resize(n)
	kinds.resize(n)
	spawn_ids.resize(n)
	colors.resize(n)
