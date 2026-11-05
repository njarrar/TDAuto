class_name TowerViewModel extends RefCounted
## Tower draw buffers (ADR-0011 Decisions 2 and 3): per slot presence, level, key, state ring
## fraction and range, plus one requested range ring. Polls TowerSim in refresh, with its own
## per-slot ReadContexts and halted() after each accessor read.

var slot_n: int = 0
var present: PackedByteArray = PackedByteArray()
var centres: PackedVector2Array = PackedVector2Array()
var levels: PackedInt32Array = PackedInt32Array()
var keys: Array[StringName] = []
## 0 when ready, else cooldown_left over the attack interval in ticks (0 to 1).
var cooling: PackedFloat32Array = PackedFloat32Array()
## Range ring request: slot index (-1 none) and radius. Set the Callable to HudLogic.range_ring_slot.
var ring_slot: int = -1
var ring_radius: float = 0.0
var ring_request: Callable = Callable()

var _tower_sim: TowerSim = null
var _accessor: StatAccessor = null
var _halted: Callable = Callable()
var _visual_keys: VisualKeys = null
var _reduce_motion: bool = false
var _dev_error: Callable = Callable()
var _ctx: Array[ReadContext] = []
var _had_content: bool = false


## Builds one ReadContext per slot.
func attach(tower_sim: TowerSim, accessor: StatAccessor, halted: Callable, visual_keys: VisualKeys,
		reduce_motion: bool, dev_error: Callable) -> bool:
	if tower_sim == null or accessor == null or visual_keys == null:
		return false
	_tower_sim = tower_sim
	_accessor = accessor
	_halted = halted
	_visual_keys = visual_keys
	_reduce_motion = reduce_motion
	_dev_error = dev_error
	slot_n = tower_sim.slot_count()
	present.resize(slot_n)
	centres.resize(slot_n)
	levels.resize(slot_n)
	cooling.resize(slot_n)
	keys.resize(slot_n)
	for i: int in range(slot_n):
		centres[i] = tower_sim.slot_position(i)
		keys[i] = &""
		_ctx.append(ReadContext.make(&"", 1))
	return true


## Frame step 4. True when the drawer must redraw.
func refresh(_view_ms: float) -> bool:
	if _tower_sim == null:
		return false
	var any: bool = false
	for i: int in range(slot_n):
		var id: StringName = _tower_sim.slot_tower(i)
		if id == &"":
			present[i] = 0
			levels[i] = 0
			cooling[i] = 0.0
			keys[i] = &""
			continue
		any = true
		present[i] = 1
		var level: int = _tower_sim.slot_level(i)
		levels[i] = level
		keys[i] = _visual_keys.tower(id, level)
		var left: int = _tower_sim.slot_cooldown_left(i)
		cooling[i] = 0.0
		if left > 0:
			_ctx[i].def_id = id
			_ctx[i].level = level
			var interval: float = _accessor.stat_float(_ctx[i], StatKeys.ATTACK_INTERVAL)
			if bool(_halted.call()):
				return false
			var total: int = maxi(1, roundi(interval * float(SimTime.TICKS_PER_SECOND)))
			cooling[i] = clampf(float(left) / float(total), 0.0, 1.0)
	ring_slot = -1
	ring_radius = 0.0
	if ring_request.is_valid():
		var want: int = ring_request.call() as int
		if want >= 0 and want < slot_n and present[want] != 0:
			_ctx[want].def_id = _tower_sim.slot_tower(want)
			_ctx[want].level = levels[want]
			var r: float = _accessor.stat_float(_ctx[want], StatKeys.RANGE)
			if bool(_halted.call()):
				return false
			ring_slot = want
			ring_radius = r
	var changed: bool = any or ring_slot >= 0 or _had_content
	_had_content = any or ring_slot >= 0
	return changed


## Drops every reference.
func detach() -> void:
	_tower_sim = null
	_accessor = null
	_halted = Callable()
	_visual_keys = null
	_dev_error = Callable()
	ring_request = Callable()
	_ctx = []
