class_name Combat extends RefCounted
## Damage, slow and targeting for one battle (ADR-0009 Decisions 3 to 6).
## Holds its counters and the `to_ticks` Callable, and nothing else: no
## Targetable, no list, no event. Reads no catalogue data.
##
## Scoped exception to ADR-0001 Decision 4: the guard codes below are reported
## with `push_error` directly. No other class may cite this exception.

enum SourceKind { TOWER, HERO, BURST }

const ERR_REMOVED := "combat: target removed"
const ERR_BAD_AMOUNT := "combat: amount negative or not finite"
const ERR_BAD_SLOW := "combat: slow strength or seconds out of range"
const ERR_BAD_MAX_HP := "combat: max_hp not finite or not above 0"
const ERR_ALREADY_ATTACHED := "combat: target already has Health or Status"
const ERR_BAD_TO_TICKS := "combat: to_ticks callable is not valid"

## Fired when an attack starts, before any damage. View only.
signal attack_fired(source_kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float)
## Fired after a hit has been committed. View only (ADR-0006).
signal damage_applied(source_kind: SourceKind, source_id: StringName, applied: float, position: Vector2, killed: bool, spawn_id: int)

var _to_ticks: Callable
## Damage dealt per source id (StringName to float).
var _dealt: Dictionary = {}
## Damage dealt per SourceKind, indexed by the enum.
var _kind_sums: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])


func _init(to_ticks: Callable) -> void:
	_to_ticks = to_ticks
	if not to_ticks.is_valid():
		push_error(ERR_BAD_TO_TICKS)


## Creates Health (seeded from max_hp) and Status on t. Checks, in order:
## t already has Health or Status: push_error(ERR_ALREADY_ATTACHED), return false.
## not is_finite(max_hp) or max_hp <= 0.0: push_error(ERR_BAD_MAX_HP), return false.
## Writes nothing on failure.
func attach(t: Targetable, max_hp: float) -> bool:
	if t.health != null or t.status != null:
		push_error(ERR_ALREADY_ATTACHED)
		return false
	if not is_finite(max_hp) or max_hp <= 0.0:
		push_error(ERR_BAD_MAX_HP)
		return false
	var h: Health = Health.new()
	h.hp = max_hp
	h.max_hp = max_hp
	t.health = h
	t.status = Status.new()
	return true


## Applies one hit. Guards in fixed order: removed, bad amount, dead. Returns
## the HP actually removed (0.0 when a guard stops it). Runs only inside a tick.
func deliver(event: DamageEvent) -> float:
	var t: Targetable = event.target
	if t.removed:
		push_error(ERR_REMOVED)
		return 0.0
	var amount: float = event.amount
	if not is_finite(amount) or amount < 0.0:
		push_error(ERR_BAD_AMOUNT)
		return 0.0
	var h: Health = t.health
	if h.hp <= 0.0:
		return 0.0
	var applied: float = minf(amount, h.hp)
	if applied == 0.0:
		return 0.0
	h.hp -= applied
	var id: StringName = event.source_id
	_dealt[id] = float(_dealt.get(id, 0.0)) + applied
	_kind_sums[event.source_kind] += applied
	damage_applied.emit(event.source_kind, id, applied, t.view_position(), h.hp <= 0.0, t.spawn_id)
	return applied


## Applies a slow. Same guard order as `deliver`. One slot: a stronger slow
## replaces it, an equal one keeps the longer time, a weaker one is ignored.
func apply_slow(t: Targetable, strength: float, seconds: float) -> void:
	if t.removed:
		push_error(ERR_REMOVED)
		return
	if not is_finite(strength) or not (strength > 0.0 and strength < 1.0) \
			or not is_finite(seconds) or not (seconds > 0.0):
		push_error(ERR_BAD_SLOW)
		return
	if t.health.hp <= 0.0:
		return
	var ticks: int = maxi(1, int(_to_ticks.call(seconds)))
	var s: Status = t.status
	if s.ticks_left <= 0 or strength > s.strength:
		s.strength = strength
		s.ticks_left = ticks
	elif strength == s.strength:
		s.ticks_left = maxi(s.ticks_left, ticks)


## Movement multiplier: 1.0 minus the slow strength while the slot is full.
func speed_factor(t: Targetable) -> float:
	var s: Status = t.status
	if s.ticks_left > 0:
		return 1.0 - s.strength
	return 1.0


## Counts every non-empty slot down by one tick. Emits nothing.
func tick_status(roster: Array[Targetable]) -> void:
	for t: Targetable in roster:
		var s: Status = t.status
		if s.ticks_left > 0:
			s.ticks_left -= 1
			if s.ticks_left <= 0:
				s.strength = 0.0
				s.ticks_left = 0


## The in-range, alive, not-removed target with the greatest `distance`; ties
## go to the lowest `spawn_id`. Null if none.
func first_in(list: Array[Targetable], origin_x: float, origin_y: float, max_range: float) -> Targetable:
	var best: Targetable = null
	var r2: float = max_range * max_range
	for t: Targetable in list:
		if t.removed or t.health.hp <= 0.0:
			continue
		var dx: float = t.pos_x - origin_x
		var dy: float = t.pos_y - origin_y
		if not (dx * dx + dy * dy <= r2):
			continue
		if best == null or t.distance > best.distance \
				or (t.distance == best.distance and t.spawn_id < best.spawn_id):
			best = t
	return best


## The in-range, alive, not-removed target nearest the origin; ties go to the
## lowest `spawn_id`. Null if none.
func nearest_in(list: Array[Targetable], origin_x: float, origin_y: float, max_range: float) -> Targetable:
	var best: Targetable = null
	var best_d2: float = 0.0
	var r2: float = max_range * max_range
	for t: Targetable in list:
		if t.removed or t.health.hp <= 0.0:
			continue
		var dx: float = t.pos_x - origin_x
		var dy: float = t.pos_y - origin_y
		var d2: float = dx * dx + dy * dy
		if not (d2 <= r2):
			continue
		if best == null or d2 < best_d2 or (d2 == best_d2 and t.spawn_id < best.spawn_id):
			best = t
			best_d2 = d2
	return best


## Every alive, not-removed target in range, in input order. A new typed array.
func all_in_radius(list: Array[Targetable], impact_x: float, impact_y: float, radius: float) -> Array[Targetable]:
	var out: Array[Targetable] = []
	var r2: float = radius * radius
	for t: Targetable in list:
		if t.removed or t.health.hp <= 0.0:
			continue
		var dx: float = t.pos_x - impact_x
		var dy: float = t.pos_y - impact_y
		if dx * dx + dy * dy <= r2:
			out.append(t)
	return out


## True at HP 0. Stays answerable after removal.
func is_dead(t: Targetable) -> bool:
	return t.health.hp <= 0.0


## Current HP.
func hp_left(t: Targetable) -> float:
	return t.health.hp


## Announces an attack to the views. Call before the attack's `deliver` calls.
func report_attack(source_kind: SourceKind, source_id: StringName, origin: Vector2, impact: Vector2, radius: float) -> void:
	attack_fired.emit(source_kind, source_id, origin, impact, radius)


## Damage dealt by one source id; 0.0 for an unknown id.
func dealt_by_id(id: StringName) -> float:
	return float(_dealt.get(id, 0.0))


## Damage dealt by one kind of source.
func dealt_by_kind(kind: SourceKind) -> float:
	return _kind_sums[kind]


## Sum of the three kind sums.
func dealt_total() -> float:
	return _kind_sums[SourceKind.TOWER] + _kind_sums[SourceKind.HERO] + _kind_sums[SourceKind.BURST]


## (HERO + BURST) / total; 0.0 when nothing has been dealt.
func hero_share() -> float:
	var total: float = dealt_total()
	if total <= 0.0:
		return 0.0
	return (_kind_sums[SourceKind.HERO] + _kind_sums[SourceKind.BURST]) / total
