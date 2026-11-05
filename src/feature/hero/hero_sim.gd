class_name HeroSim extends RefCounted
## The hero: pin, walk, auto-attack and the burst (Hero GDD, ADR-0010).
## Headless. Every stored position is a float pair; Vector2 arguments are
## converted on entry, and Vector2 is built only for returns and payloads.

enum PinResult { OK = 0, HALTED = 1, BAD_POSITION = 2, OUT_OF_BOUNDS = 3, BUTTON_ZONE = 4 }
enum BurstResult { OK = 0, HALTED = 1, BUILD_PHASE = 2, NOT_PINNED = 3, NOT_READY = 4,
		BAD_POSITION = 5, OFF_FIELD = 6, OUT_OF_REACH = 7 }
enum PinState { UNPINNED, WALKING, PINNED }
enum BurstState { READY, TELEGRAPHING, COOLING }

## Tolerance in walk_ticks so float error adds no tick (Hero Formulas).
const WALK_EPS: float = 0.0001

## P6. Inside pin() after state is set.
signal hero_pinned(position: Vector2)
## P7. Inside burst() after state is set.
signal burst_started(aim_point: Vector2, telegraph_ticks: int)

var _stage: StageRecord
var _hero_id: StringName
var _burst_id: StringName
var _accessor: StatAccessor
var _halted: Callable
var _between_ticks: Callable
var _in_build: Callable
var _targets: Callable
var _to_ticks: Callable
var _dt: float
var _combat: Combat
var _fatal: Callable
var _geometry: PinGeometry
var _hero_ctx: ReadContext
var _burst_ctx: ReadContext

var _pos_x: float = 0.0
var _pos_y: float = 0.0
var _from_x: float = 0.0
var _from_y: float = 0.0
var _pin_x: float = 0.0
var _pin_y: float = 0.0
var _aim_x: float = 0.0
var _aim_y: float = 0.0
var _pin_state: PinState = PinState.UNPINNED
var _burst_state: BurstState = BurstState.READY
var _has_pinned: bool = false
var _walk_left: int = 0
var _walk_ticks: int = 0
var _attack_left: int = 0
var _cooldown_left: int = 0
var _telegraph_left: int = 0

var _repins: int = 0
var _bursts_fired: int = 0
var _bursts_hit_0: int = 0
var _bursts_hit_3: int = 0
var _bursts_hit_5: int = 0
var _burst_victims: int = 0
var _burst_kills: int = 0
var _kills_per_burst: PackedInt32Array = PackedInt32Array()
var _kills_on_hit_3: PackedInt32Array = PackedInt32Array()
var _best_victims: PackedInt32Array = PackedInt32Array()


func _init(stage: StageRecord, p_hero_id: StringName, p_burst_id: StringName, left_handed: bool,
		accessor: StatAccessor, halted: Callable, between_ticks: Callable, in_build: Callable,
		targets: Callable, to_ticks: Callable, dt: float, combat: Combat, fatal: Callable) -> void:
	_stage = stage
	_hero_id = p_hero_id
	_burst_id = p_burst_id
	_accessor = accessor
	_halted = halted
	_between_ticks = between_ticks
	_in_build = in_build
	_targets = targets
	_to_ticks = to_ticks
	_dt = dt
	_combat = combat
	_fatal = fatal
	_geometry = PinGeometry.new(stage, left_handed)
	_hero_ctx = ReadContext.make(p_hero_id, 0)
	_burst_ctx = ReadContext.make(p_burst_id, 0)
	_pos_x = stage.hero_start[0]
	_pos_y = stage.hero_start[1]
	_pin_x = _pos_x
	_pin_y = _pos_y


## Pins the hero at pos. Check order: between ticks, halted, finite, rect and
## button zone, then the WALK_SPEED read. A refusal changes nothing.
func pin(pos: Vector2) -> PinResult:
	if not bool(_between_ticks.call()):
		_fatal.call("command inside tick: HeroSim.pin")
		return PinResult.HALTED
	if bool(_halted.call()):
		return PinResult.HALTED
	var x: float = pos.x
	var y: float = pos.y
	if not is_finite(x) or not is_finite(y):
		return PinResult.BAD_POSITION
	var geometry: PinResult = _geometry.is_valid(x, y)
	if geometry != PinResult.OK:
		return geometry
	var speed: float = _accessor.stat_float(_hero_ctx, StatKeys.WALK_SPEED)
	if bool(_halted.call()):
		return PinResult.HALTED
	var dx: float = x - _pos_x
	var dy: float = y - _pos_y
	var distance: float = sqrt(dx * dx + dy * dy)
	if distance > 0.0:
		if _has_pinned:
			_repins += 1
		var per_tick: float = speed * _dt
		var ticks: int = 1
		if per_tick > 0.0:
			ticks = maxi(1, ceili(distance / per_tick - WALK_EPS))
		_walk_ticks = ticks
		_walk_left = ticks
		_from_x = _pos_x
		_from_y = _pos_y
		_pin_state = PinState.WALKING
	else:
		_pin_state = PinState.PINNED
	_pin_x = x
	_pin_y = y
	_has_pinned = true
	hero_pinned.emit(Vector2(x, y))
	return PinResult.OK


## Starts the burst at aim_point. Check order: between ticks, halted, build
## phase, pinned, ready, finite, field, reach read and test, telegraph read.
func burst(aim_point: Vector2) -> BurstResult:
	if not bool(_between_ticks.call()):
		_fatal.call("command inside tick: HeroSim.burst")
		return BurstResult.HALTED
	if bool(_halted.call()):
		return BurstResult.HALTED
	if _in_build.is_valid() and bool(_in_build.call()):
		return BurstResult.BUILD_PHASE
	if not _has_pinned:
		return BurstResult.NOT_PINNED
	if _burst_state != BurstState.READY:
		return BurstResult.NOT_READY
	var x: float = aim_point.x
	var y: float = aim_point.y
	if not is_finite(x) or not is_finite(y):
		return BurstResult.BAD_POSITION
	if x < 0.0 or x > FieldBounds.WIDTH or y < 0.0 or y > FieldBounds.HEIGHT:
		return BurstResult.OFF_FIELD
	var reach: float = _accessor.stat_float(_burst_ctx, StatKeys.REACH)
	if bool(_halted.call()):
		return BurstResult.HALTED
	var dx: float = x - _pos_x
	var dy: float = y - _pos_y
	if dx * dx + dy * dy > reach * reach:
		return BurstResult.OUT_OF_REACH
	var telegraph: float = _accessor.stat_float(_burst_ctx, StatKeys.TELEGRAPH_DURATION)
	if bool(_halted.call()):
		return BurstResult.HALTED
	_aim_x = x
	_aim_y = y
	_telegraph_left = maxi(1, int(_to_ticks.call(telegraph)))
	_burst_state = BurstState.TELEGRAPHING
	burst_started.emit(Vector2(x, y), _telegraph_left)
	return BurstResult.OK


## Battle step 5 only: walk, attack, cooldown, telegraph, release.
func tick() -> void:
	if bool(_halted.call()):
		return
	if _pin_state == PinState.WALKING:
		_walk_left -= 1
		if _walk_left <= 0:
			_pos_x = _pin_x
			_pos_y = _pin_y
			_pin_state = PinState.PINNED
		else:
			var ratio: float = 1.0 - float(_walk_left) / float(_walk_ticks)
			_pos_x = _from_x + (_pin_x - _from_x) * ratio
			_pos_y = _from_y + (_pin_y - _from_y) * ratio
	if _attack_left > 0:
		_attack_left -= 1
	if _pin_state == PinState.PINNED and _attack_left <= 0:
		if not _attack():
			return
	if _burst_state == BurstState.COOLING:
		_cooldown_left -= 1
		if _cooldown_left <= 0:
			_cooldown_left = 0
			_burst_state = BurstState.READY
	if _burst_state == BurstState.TELEGRAPHING:
		_telegraph_left -= 1
		if _telegraph_left <= 0:
			_release()


## Current position, built from the floats. For views and bots only.
func position() -> Vector2:
	return Vector2(_pos_x, _pos_y)


## The pin target; hero_start before a first pin.
func pin_target() -> Vector2:
	return Vector2(_pin_x, _pin_y)


func pin_state() -> PinState:
	return _pin_state


func burst_state() -> BurstState:
	return _burst_state


func cooldown_left() -> int:
	return _cooldown_left


func hero_id() -> StringName:
	return _hero_id


func burst_id() -> StringName:
	return _burst_id


func repins() -> int:
	return _repins


func bursts_fired() -> int:
	return _bursts_fired


func bursts_hit_0() -> int:
	return _bursts_hit_0


func bursts_hit_3() -> int:
	return _bursts_hit_3


func bursts_hit_5() -> int:
	return _bursts_hit_5


func burst_victims() -> int:
	return _burst_victims


func burst_kills() -> int:
	return _burst_kills


## A copy: kills of every release, a 0 included.
func kills_per_burst() -> PackedInt32Array:
	return _kills_per_burst.duplicate()


## A copy: kills of each burst that had 3 or more victims.
func kills_on_hit_3() -> PackedInt32Array:
	return _kills_on_hit_3.duplicate()


## A copy: per release, the most targets() a burst-radius disc centred on an
## enemy held at that moment.
func best_victims() -> PackedInt32Array:
	return _best_victims.duplicate()


## Every field as JSON-native values, for digests. Allocates.
func state_fields() -> Dictionary:
	return {
		"pos_x": _pos_x, "pos_y": _pos_y, "pin_x": _pin_x, "pin_y": _pin_y,
		"aim_x": _aim_x, "aim_y": _aim_y,
		"pin_state": int(_pin_state), "burst_state": int(_burst_state),
		"has_pinned": _has_pinned, "walk_left": _walk_left, "walk_ticks": _walk_ticks,
		"attack_left": _attack_left, "cooldown_left": _cooldown_left,
		"telegraph_left": _telegraph_left,
		"repins": _repins, "bursts_fired": _bursts_fired, "bursts_hit_0": _bursts_hit_0,
		"bursts_hit_3": _bursts_hit_3, "bursts_hit_5": _bursts_hit_5,
		"burst_victims": _burst_victims, "burst_kills": _burst_kills,
		"kills_per_burst": Array(_kills_per_burst), "kills_on_hit_3": Array(_kills_on_hit_3),
		"best_victims": Array(_best_victims),
	}


## Auto-attack step. Returns false when halted (end the tick).
func _attack() -> bool:
	var leash: float = _accessor.stat_float(_hero_ctx, StatKeys.LEASH_RADIUS)
	if bool(_halted.call()):
		return false
	var list: Array[Targetable] = _targets.call()
	var target: Targetable = _combat.nearest_in(list, _pos_x, _pos_y, leash)
	if target == null:
		return true
	var damage: float = _accessor.stat_float(_hero_ctx, StatKeys.DAMAGE)
	if bool(_halted.call()):
		return false
	var interval: float = _accessor.stat_float(_hero_ctx, StatKeys.ATTACK_INTERVAL)
	if bool(_halted.call()):
		return false
	_attack_left = int(_to_ticks.call(interval))
	_combat.report_attack(Combat.SourceKind.HERO, _hero_id, Vector2(_pos_x, _pos_y),
			Vector2(target.pos_x, target.pos_y), 0.0)
	if bool(_halted.call()):
		return false
	_combat.deliver(DamageEvent.make(target, damage, Combat.SourceKind.HERO, _hero_id))
	return not bool(_halted.call())


## Burst release: reads, Cooling, victims, report, delivers, counters.
func _release() -> void:
	var radius: float = _accessor.stat_float(_burst_ctx, StatKeys.RADIUS)
	if bool(_halted.call()):
		return
	var damage: float = _accessor.stat_float(_burst_ctx, StatKeys.DAMAGE)
	if bool(_halted.call()):
		return
	var cooldown: float = _accessor.stat_float(_burst_ctx, StatKeys.COOLDOWN)
	if bool(_halted.call()):
		return
	_burst_state = BurstState.COOLING
	_cooldown_left = int(_to_ticks.call(cooldown))
	_telegraph_left = 0
	var list: Array[Targetable] = _targets.call()
	var best: int = _best_disc(list, radius)
	var victims: Array[Targetable] = _combat.all_in_radius(list, _aim_x, _aim_y, radius)
	_combat.report_attack(Combat.SourceKind.BURST, _burst_id, Vector2(_pos_x, _pos_y),
			Vector2(_aim_x, _aim_y), radius)
	if bool(_halted.call()):
		return
	var hit: int = 0
	var kills: int = 0
	for v: Targetable in victims:
		var applied: float = _combat.deliver(
				DamageEvent.make(v, damage, Combat.SourceKind.BURST, _burst_id))
		if bool(_halted.call()):
			return
		if applied > 0.0:
			hit += 1
			if _combat.is_dead(v):
				kills += 1
	_bursts_fired += 1
	if hit == 0:
		_bursts_hit_0 += 1
	if hit >= 3:
		_bursts_hit_3 += 1
		_kills_on_hit_3.append(kills)
	if hit >= 5:
		_bursts_hit_5 += 1
	_burst_victims += hit
	_burst_kills += kills
	_kills_per_burst.append(kills)
	_best_victims.append(best)


## The most live targets a disc of `radius` centred on one target holds.
func _best_disc(list: Array[Targetable], radius: float) -> int:
	var r2: float = radius * radius
	var best: int = 0
	for a: Targetable in list:
		if a.removed or _combat.is_dead(a):
			continue
		var count: int = 0
		for b: Targetable in list:
			if b.removed or _combat.is_dead(b):
				continue
			var dx: float = b.pos_x - a.pos_x
			var dy: float = b.pos_y - a.pos_y
			if dx * dx + dy * dy <= r2:
				count += 1
		best = maxi(best, count)
	return best
