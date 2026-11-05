extends RefCounted
## Fixtures for Combat tests (ADR-0009, Combat GDD Acceptance Criteria).
## No class_name; tests preload this file by path. Values are multiples of 1/4.


## Records Combat's two signals with their payloads, as plain values.
class Log extends RefCounted:
	var attacks: Array[Dictionary] = []
	var hits: Array[Dictionary] = []

	func on_attack_fired(kind: Combat.SourceKind, id: StringName, origin: Vector2, impact: Vector2, radius: float) -> void:
		attacks.append({"kind": kind, "id": id, "origin": origin, "impact": impact, "radius": radius})

	func on_damage_applied(kind: Combat.SourceKind, id: StringName, applied: float, position: Vector2, killed: bool, spawn_id: int) -> void:
		hits.append({"kind": kind, "id": id, "applied": applied, "position": position, "killed": killed, "spawn_id": spawn_id})

	func applied_sum() -> float:
		var total: float = 0.0
		for h: Dictionary in hits:
			total += float(h["applied"])
		return total


## A Combat whose to_ticks is a SimTime at `ticks_per_second` (4 gives dt 0.25).
## The caller must keep `sim_time` alive: a Callable does not hold its object.
static func make_combat(sim_time: SimTime) -> Combat:
	return Combat.new(sim_time.to_ticks)


## Connects a log to a combat.
static func listen(combat: Combat, rec: Log) -> void:
	combat.attack_fired.connect(rec.on_attack_fired)
	combat.damage_applied.connect(rec.on_damage_applied)


## A Targetable attached through Combat, at (x, y) with the given distance.
static func target(combat: Combat, spawn_id: int, hp: float, x: float = 0.0, y: float = 0.0, dist: float = 0.0) -> Targetable:
	var t: Targetable = Targetable.new(spawn_id)
	var ok: bool = combat.attach(t, hp)
	if not ok:
		return null
	t.pos_x = x
	t.pos_y = y
	t.distance = dist
	return t


## The invariant I: sum of logged `applied` equals the sum of counters equals
## the sum of (max_hp - hp) over every target the test created.
static func invariant_holds(combat: Combat, rec: Log, all: Array[Targetable]) -> bool:
	var lost: float = 0.0
	for t: Targetable in all:
		lost += t.health.max_hp - t.health.hp
	var by_kind: float = combat.dealt_by_kind(Combat.SourceKind.TOWER) \
			+ combat.dealt_by_kind(Combat.SourceKind.HERO) \
			+ combat.dealt_by_kind(Combat.SourceKind.BURST)
	return rec.applied_sum() == combat.dealt_total() and combat.dealt_total() == by_kind \
			and by_kind == lost
