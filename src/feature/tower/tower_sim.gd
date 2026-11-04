class_name TowerSim extends RefCounted
## Gold, tower slots, the build and upgrade commands and the tower tick
## (Tower GDD, ADR-0010 Decisions 2 to 7, ADR-0005 Decision 7).
## Headless. Slot positions are read from the stage as float pairs.

enum BuildResult { OK = 0, HALTED = 1, BAD_SLOT = 2, BAD_TOWER = 3, SLOT_OCCUPIED = 4, NO_GOLD = 5 }
enum UpgradeResult { OK = 0, HALTED = 1, BAD_SLOT = 2, NO_TOWER = 3, MAX_LEVEL = 4, NO_GOLD = 5 }

const ROLE_SPLASH: StringName = &"splash"
const ROLE_SLOW: StringName = &"slow"

## P3. After build or upgrade commit and before P4 or P5; inside W2 and W5
## handlers. Only on a change.
signal gold_changed(current: int)
## P4. After gold_changed in build.
signal tower_built(slot_index: int, tower_id: StringName)
## P5. After gold_changed in upgrade.
signal tower_upgraded(slot_index: int, level: int)

var _stage: StageRecord
var _accessor: StatAccessor
var _halted: Callable
var _between_ticks: Callable
var _targets: Callable
var _to_ticks: Callable
var _combat: Combat
var _fatal: Callable
var _dev_error: Callable

var _gold: int = 0
var _slot_n: int = 0
var _rate_ticks: int = 1
var _slows_applied: int = 0
var _bad_index_reported: bool = false
var _slot_tower: Array[StringName] = []
var _slot_level: PackedInt32Array = PackedInt32Array()
var _slot_cooldown: PackedInt32Array = PackedInt32Array()
var _slot_ctx: Array[ReadContext] = []
var _cost_ctx: ReadContext
var _unslowed: Array[Targetable] = []
var _single_victim: Array[Targetable] = []


func _init(stage: StageRecord, accessor: StatAccessor, halted: Callable, between_ticks: Callable,
		targets: Callable, to_ticks: Callable, combat: Combat, fatal: Callable,
		dev_error: Callable) -> void:
	_stage = stage
	_accessor = accessor
	_halted = halted
	_between_ticks = between_ticks
	_targets = targets
	_to_ticks = to_ticks
	_combat = combat
	_fatal = fatal
	_dev_error = dev_error
	_gold = stage.starting_gold
	_slot_n = stage.slot_count()
	for i: int in range(_slot_n):
		_slot_tower.append(&"")
		_slot_level.append(0)
		_slot_cooldown.append(0)
		_slot_ctx.append(ReadContext.make(&"", 0))
	_cost_ctx = ReadContext.make(&"", 0)
	_rate_ticks = int(to_ticks.call(stage.early_call_seconds_per_gold))
	if _rate_ticks < 1:
		_rate_ticks = 1
		_fatal.call("stage: early_call_seconds_per_gold under one tick")


## Builds tower_id on an empty slot. Check order: between ticks, halted, slot,
## tower, occupied, cost read, gold.
func build(slot_index: int, tower_id: StringName) -> BuildResult:
	if not bool(_between_ticks.call()):
		_fatal.call("command inside tick: TowerSim.build")
		return BuildResult.HALTED
	if bool(_halted.call()):
		return BuildResult.HALTED
	if slot_index < 0 or slot_index >= _slot_n:
		return BuildResult.BAD_SLOT
	if not _accessor.is_tower(tower_id):
		return BuildResult.BAD_TOWER
	if _slot_tower[slot_index] != &"":
		return BuildResult.SLOT_OCCUPIED
	_cost_ctx.def_id = tower_id
	_cost_ctx.level = 1
	var cost: int = _accessor.stat_int(_cost_ctx, StatKeys.COST)
	if bool(_halted.call()):
		return BuildResult.HALTED
	if _gold < cost:
		return BuildResult.NO_GOLD
	_gold -= cost
	_slot_tower[slot_index] = tower_id
	_slot_level[slot_index] = 1
	_slot_cooldown[slot_index] = 0
	var ctx: ReadContext = _slot_ctx[slot_index]
	ctx.def_id = tower_id
	ctx.level = 1
	if cost != 0:
		gold_changed.emit(_gold)
		if bool(_halted.call()):
			return BuildResult.OK
	tower_built.emit(slot_index, tower_id)
	return BuildResult.OK


## Raises the tower in a slot by one level. The cooldown is left alone.
func upgrade(slot_index: int) -> UpgradeResult:
	if not bool(_between_ticks.call()):
		_fatal.call("command inside tick: TowerSim.upgrade")
		return UpgradeResult.HALTED
	if bool(_halted.call()):
		return UpgradeResult.HALTED
	if slot_index < 0 or slot_index >= _slot_n:
		return UpgradeResult.BAD_SLOT
	var def_id: StringName = _slot_tower[slot_index]
	if def_id == &"":
		return UpgradeResult.NO_TOWER
	var level: int = _slot_level[slot_index]
	if level >= _accessor.level_count(def_id):
		return UpgradeResult.MAX_LEVEL
	_cost_ctx.def_id = def_id
	_cost_ctx.level = level + 1
	var cost: int = _accessor.stat_int(_cost_ctx, StatKeys.COST)
	if bool(_halted.call()):
		return UpgradeResult.HALTED
	if _gold < cost:
		return UpgradeResult.NO_GOLD
	_gold -= cost
	_slot_level[slot_index] = level + 1
	_slot_ctx[slot_index].level = level + 1
	if cost != 0:
		gold_changed.emit(_gold)
		if bool(_halted.call()):
			return UpgradeResult.OK
	tower_upgraded.emit(slot_index, level + 1)
	return UpgradeResult.OK


## Battle step 4 only. Slots run by ascending index.
func tick() -> void:
	if bool(_halted.call()):
		return
	for i: int in range(_slot_n):
		if _slot_tower[i] == &"":
			continue
		if _slot_cooldown[i] > 0:
			_slot_cooldown[i] -= 1
			if _slot_cooldown[i] > 0:
				continue
		if not _fire_slot(i):
			return


## W2 only. Adds the bounty to gold.
func on_enemy_killed(bounty: int) -> void:
	if bool(_halted.call()):
		return
	if bounty <= 0:
		return
	_gold += bounty
	gold_changed.emit(_gold)


## W5 only. Pays to_ticks(seconds_left) div to_ticks(rate), whole division.
func on_wave_called_early(seconds_left: float) -> void:
	if bool(_halted.call()):
		return
	var ticks_left: int = maxi(0, int(_to_ticks.call(seconds_left)))
	@warning_ignore("integer_division")
	var bonus: int = ticks_left / _rate_ticks
	if bonus <= 0:
		return
	_gold += bonus
	gold_changed.emit(_gold)


## The one gold total.
func gold() -> int:
	return _gold


## Number of slots.
func slot_count() -> int:
	return _slot_n


## Tower ID in the slot, &"" when empty or on a bad index.
func slot_tower(i: int) -> StringName:
	if not _index_ok(i, "slot_tower"):
		return &""
	return _slot_tower[i]


## Level in the slot, 0 when empty or on a bad index.
func slot_level(i: int) -> int:
	if not _index_ok(i, "slot_level"):
		return 0
	return _slot_level[i]


## Ticks until the slot's tower is ready, 0 when empty or on a bad index.
func slot_cooldown_left(i: int) -> int:
	if not _index_ok(i, "slot_cooldown_left"):
		return 0
	return _slot_cooldown[i]


## The slot's centre as a Vector2, for views and bots only.
func slot_position(i: int) -> Vector2:
	if not _index_ok(i, "slot_position"):
		return Vector2(0.0, 0.0)
	return Vector2(_stage.slot_positions[2 * i], _stage.slot_positions[2 * i + 1])


## Count of apply_slow calls made so far.
func slows_applied() -> int:
	return _slows_applied


## Every field as JSON-native values, for digests. Allocates.
func state_fields() -> Dictionary:
	var slots: Array = []
	for i: int in range(_slot_n):
		slots.append({
			"tower": String(_slot_tower[i]),
			"level": _slot_level[i],
			"cooldown": _slot_cooldown[i],
		})
	return {"gold": _gold, "slots": slots, "slows_applied": _slows_applied}


func _index_ok(i: int, method: String) -> bool:
	if i >= 0 and i < _slot_n:
		return true
	if not _bad_index_reported:
		_bad_index_reported = true
		if _dev_error.is_valid():
			_dev_error.call("TowerSim.%s: bad slot index %d" % [method, i])
	return false


## One tower's attack step. Returns false when halted (stop the whole tick).
func _fire_slot(i: int) -> bool:
	var ctx: ReadContext = _slot_ctx[i]
	var tower_id: StringName = _slot_tower[i]
	var reach: float = _accessor.stat_float(ctx, StatKeys.RANGE)
	if bool(_halted.call()):
		return false
	var ox: float = _stage.slot_positions[2 * i]
	var oy: float = _stage.slot_positions[2 * i + 1]
	var list: Array[Targetable] = _targets.call()
	var is_slow: bool = _accessor.has_tag(tower_id, ROLE_SLOW)
	var is_splash: bool = _accessor.has_tag(tower_id, ROLE_SPLASH)
	var target: Targetable = null
	if is_slow:
		_unslowed.clear()
		for t: Targetable in list:
			if _combat.speed_factor(t) == 1.0:
				_unslowed.append(t)
		target = _combat.first_in(_unslowed, ox, oy, reach)
	if target == null:
		target = _combat.first_in(list, ox, oy, reach)
	if target == null:
		return true
	var damage: float = _accessor.stat_float(ctx, StatKeys.DAMAGE)
	if bool(_halted.call()):
		return false
	var interval: float = _accessor.stat_float(ctx, StatKeys.ATTACK_INTERVAL)
	if bool(_halted.call()):
		return false
	var radius: float = 0.0
	if is_splash:
		radius = _accessor.stat_float(ctx, StatKeys.SPLASH_RADIUS)
		if bool(_halted.call()):
			return false
	var strength: float = 0.0
	var seconds: float = 0.0
	if is_slow:
		strength = _accessor.stat_float(ctx, StatKeys.SLOW_STRENGTH)
		if bool(_halted.call()):
			return false
		seconds = _accessor.stat_float(ctx, StatKeys.SLOW_DURATION)
		if bool(_halted.call()):
			return false
	_slot_cooldown[i] = int(_to_ticks.call(interval))
	_combat.report_attack(Combat.SourceKind.TOWER, tower_id, Vector2(ox, oy),
			Vector2(target.pos_x, target.pos_y), radius)
	if bool(_halted.call()):
		return false
	var victims: Array[Targetable] = _single_victim
	if is_splash:
		victims = _combat.all_in_radius(list, target.pos_x, target.pos_y, radius)
	else:
		_single_victim.clear()
		_single_victim.append(target)
	for v: Targetable in victims:
		_combat.deliver(DamageEvent.make(v, damage, Combat.SourceKind.TOWER, tower_id))
		if bool(_halted.call()):
			return false
	if is_slow:
		for v: Targetable in victims:
			_combat.apply_slow(v, strength, seconds)
			_slows_applied += 1
	return true
