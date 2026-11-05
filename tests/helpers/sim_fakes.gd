extends RefCounted
## Fakes for the Flow, TowerSim and HeroSim unit tests. No class_name; tests
## preload this file by path. Combat is faked here so these tests need only
## the interface of ADR-0009 (deliver, targeting helpers, report_attack).


## A settable halted() stub.
class Halt extends RefCounted:
	var on: bool = false

	func is_halted() -> bool:
		return on


## A settable between_ticks() stub.
class Between extends RefCounted:
	var ok: bool = true

	func is_between() -> bool:
		return ok


## A settable in_build() stub.
class Build extends RefCounted:
	var on: bool = false

	func is_build() -> bool:
		return on


## Records fatal causes and latches a Halt, like the FatalRelay.
class FatalLog extends RefCounted:
	var causes: Array[String] = []
	var halt: Halt = null

	func fatal(cause: String) -> void:
		causes.append(cause)
		if halt != null:
			halt.on = true


## Records dev errors.
class DevLog extends RefCounted:
	var messages: Array[String] = []

	func report(msg: String) -> void:
		messages.append(msg)


## Counts calls.
class Counter extends RefCounted:
	var calls: int = 0

	func hit() -> void:
		calls += 1


## Fake EnemyWave side of Flow: counts next-wave starts.
class WaveStub extends RefCounted:
	var starts: int = 0

	func start_next_wave() -> void:
		starts += 1

	func wave_index() -> int:
		return starts


## Fake targets() source.
class Roster extends RefCounted:
	var list: Array[Targetable] = []

	func targets() -> Array[Targetable]:
		return list


## One ordered signal log. Methods are connected by tests.
class Recorder extends RefCounted:
	var entries: Array[String] = []

	func on_phase(value: int) -> void:
		entries.append("phase:%d" % value)

	func on_lives(current: int) -> void:
		entries.append("lives:%d" % current)

	func on_called(seconds_left: float) -> void:
		entries.append("called:%s" % str(seconds_left))

	func on_gold(current: int) -> void:
		entries.append("gold:%d" % current)

	func on_built(slot_index: int, tower_id: StringName) -> void:
		entries.append("built:%d:%s:%d" % [slot_index, tower_id, typeof(tower_id)])

	func on_upgraded(slot_index: int, level: int) -> void:
		entries.append("upgraded:%d:%d" % [slot_index, level])

	func on_pinned(position: Vector2) -> void:
		entries.append("pinned:%s,%s" % [str(position.x), str(position.y)])

	func on_burst(aim_point: Vector2, telegraph_ticks: int) -> void:
		entries.append("burst:%s,%s:%d" % [str(aim_point.x), str(aim_point.y), telegraph_ticks])


## Spy accessor: scripted values, a read log, and a latch on a chosen key.
class SpyAccessor extends StatAccessor:
	var values: Dictionary = {}
	var levels: Dictionary = {}
	var tags: Dictionary = {}
	var reads: Array[String] = []
	var halt: Halt = null
	var latch_key: StringName = &""

	func _init(fatal: Callable) -> void:
		super(null, fatal)

	func set_value(def_id: StringName, level: int, key: StringName, value: float) -> void:
		values["%s|%d|%s" % [def_id, level, key]] = value

	func stat_int(ctx: ReadContext, key: StringName) -> int:
		return int(_read(ctx, key))

	func stat_float(ctx: ReadContext, key: StringName) -> float:
		return _read(ctx, key)

	func is_tower(id: StringName) -> bool:
		return levels.has(id)

	func level_count(def_id: StringName) -> int:
		return int(levels.get(def_id, 0))

	func has_tag(def_id: StringName, tag: StringName) -> bool:
		return (tags.get(def_id, []) as Array).has(tag)

	func _read(ctx: ReadContext, key: StringName) -> float:
		reads.append("%s|%d|%s" % [ctx.def_id, ctx.level, key])
		if halt != null and key == latch_key:
			halt.on = true
		return float(values.get("%s|%d|%s" % [ctx.def_id, ctx.level, key], 0.0))


## Fake Combat: simple scalar targeting helpers and a trace of every call.
class FakeCombat extends Combat:
	var trace: Array[String] = []
	var dead_ids: Dictionary = {}
	var zero_ids: Dictionary = {}
	var slowed_ids: Dictionary = {}
	var on_trace: Callable = Callable()

	func _init(to_ticks: Callable) -> void:
		super(to_ticks)

	func deliver(event: DamageEvent) -> float:
		_note("deliver:%d:%s:%d:%s" % [event.target.spawn_id, str(event.amount),
				int(event.source_kind), event.source_id])
		if zero_ids.has(event.target.spawn_id):
			return 0.0
		return event.amount

	func apply_slow(t: Targetable, strength: float, seconds: float) -> void:
		_note("slow:%d:%s:%s" % [t.spawn_id, str(strength), str(seconds)])

	func speed_factor(t: Targetable) -> float:
		return 0.5 if slowed_ids.has(t.spawn_id) else 1.0

	func is_dead(t: Targetable) -> bool:
		return dead_ids.has(t.spawn_id)

	func report_attack(source_kind: SourceKind, source_id: StringName, origin: Vector2,
			impact: Vector2, radius: float) -> void:
		_note("attack:%d:%s:%s:%s:%s" % [int(source_kind), source_id, str(radius),
				str(impact.x), str(impact.y)])

	func first_in(list: Array[Targetable], origin_x: float, origin_y: float,
			max_range: float) -> Targetable:
		var best: Targetable = null
		for t: Targetable in list:
			if not _within(t, origin_x, origin_y, max_range):
				continue
			if best == null or t.distance > best.distance \
					or (t.distance == best.distance and t.spawn_id < best.spawn_id):
				best = t
		return best

	func nearest_in(list: Array[Targetable], origin_x: float, origin_y: float,
			max_range: float) -> Targetable:
		var best: Targetable = null
		var best_d2: float = 0.0
		for t: Targetable in list:
			if not _within(t, origin_x, origin_y, max_range):
				continue
			var dx: float = t.pos_x - origin_x
			var dy: float = t.pos_y - origin_y
			var d2: float = dx * dx + dy * dy
			if best == null or d2 < best_d2 or (d2 == best_d2 and t.spawn_id < best.spawn_id):
				best = t
				best_d2 = d2
		return best

	func all_in_radius(list: Array[Targetable], impact_x: float, impact_y: float,
			radius: float) -> Array[Targetable]:
		var out: Array[Targetable] = []
		for t: Targetable in list:
			if _within(t, impact_x, impact_y, radius):
				out.append(t)
		return out

	func _within(t: Targetable, x: float, y: float, r: float) -> bool:
		if t.removed or dead_ids.has(t.spawn_id):
			return false
		var dx: float = t.pos_x - x
		var dy: float = t.pos_y - y
		return dx * dx + dy * dy <= r * r

	func _note(line: String) -> void:
		trace.append(line)
		if on_trace.is_valid():
			on_trace.call(line)


## A Targetable at a point with a path distance.
static func target(spawn_id: int, x: float, y: float, dist: float = 0.0) -> Targetable:
	var t: Targetable = Targetable.new(spawn_id)
	t.pos_x = x
	t.pos_y = y
	t.distance = dist
	return t
