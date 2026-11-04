extends RefCounted
## Fixtures for Enemy & Wave tests (ADR-0009, Enemy & Wave GDD Acceptance
## Criteria). No class_name; tests preload this file by path. The factory
## stage matches the GDD: dt 0.25, path (-20, 950), (10, 950), (10, 980)
## (length 60), enemy speed 40 (a step of 10), bounty 4, cost 1.

const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")

const GRUNT: StringName = &"enemy_grunt"
const OTHER: StringName = &"enemy_b"


## Fake `halted`, `fatal` and `dev_error`. `fatal` latches halted, as the real
## FatalLatch does.
class Spy extends RefCounted:
	var is_halted: bool = false
	var fatals: Array[String] = []
	var dev_errors: Array[String] = []

	func halted() -> bool:
		return is_halted

	func fatal(cause: String) -> void:
		fatals.append(cause)
		is_halted = true

	func dev_error(msg: String) -> void:
		dev_errors.append(msg)


## Records EnemyWave's four signals as text lines.
class Log extends RefCounted:
	var lines: Array[String] = []

	func on_leaked(cost: int) -> void:
		lines.append("leaked(%d)" % cost)

	func on_killed(bounty: int) -> void:
		lines.append("killed(%d)" % bounty)

	func on_cleared(intermission: float) -> void:
		lines.append("cleared(%s)" % str(intermission))

	func on_completed() -> void:
		lines.append("completed")


## A StatAccessor whose reads a test can change, count and turn into a halt.
class SpyAccessor extends StatAccessor:
	var float_overrides: Dictionary = {}
	var int_overrides: Dictionary = {}
	## key -> {spawn_id -> int}
	var int_by_spawn: Dictionary = {}
	var spy: Spy = null
	var latch_key: StringName = &""
	var latch_on_read: int = 0
	var _reads: Dictionary = {}

	func _init(p_catalogue: Catalogue, p_fatal: Callable) -> void:
		super(p_catalogue, p_fatal)

	func reads_of(key: StringName) -> int:
		return int(_reads.get(key, 0))

	## Halts during the next read of `key`.
	func latch_next(key: StringName) -> void:
		latch_key = key
		latch_on_read = reads_of(key) + 1

	func stat_float(ctx: ReadContext, key: StringName) -> float:
		_note(key)
		if float_overrides.has(key):
			return float(float_overrides[key])
		return super.stat_float(ctx, key)

	func stat_int(ctx: ReadContext, key: StringName) -> int:
		_note(key)
		var who: Targetable = ctx.live_entity as Targetable
		if who != null and int_by_spawn.has(key):
			var per: Dictionary = int_by_spawn[key]
			if per.has(who.spawn_id):
				return int(per[who.spawn_id])
		if int_overrides.has(key):
			return int(int_overrides[key])
		return super.stat_int(ctx, key)

	func _note(key: StringName) -> void:
		var n: int = reads_of(key) + 1
		_reads[key] = n
		if key == latch_key and n == latch_on_read and spy != null:
			spy.is_halted = true


## Reads the wave's state inside signal handlers, and can act on them.
class Probe extends RefCounted:
	var wave: EnemyWave
	var spy: Spy
	var halt_on_first_leak: bool = false
	var add_on_kill: bool = false
	var _added: bool = false
	var roster_sizes_at_leak: Array[int] = []
	var first_id_at_leak: Array[int] = []
	var states_at_clear: Array[int] = []
	var index_at_clear: Array[int] = []
	var states_at_completed: Array[int] = []

	func on_leaked(_cost: int) -> void:
		roster_sizes_at_leak.append(wave.roster().size())
		if not wave.roster().is_empty():
			first_id_at_leak.append(wave.roster()[0].spawn_id)
		if halt_on_first_leak:
			spy.is_halted = true

	func on_killed(_bounty: int) -> void:
		if add_on_kill and not _added:
			_added = true
			wave.add_enemy(GRUNT, 0.0)

	func on_cleared(_intermission: float) -> void:
		states_at_clear.append(int(wave.wave_state()))
		index_at_clear.append(wave.wave_index())

	func on_completed() -> void:
		states_at_completed.append(int(wave.wave_state()))


## Everything one test needs. Holds the SimTime so its `to_ticks` stays valid.
class Rig extends RefCounted:
	var sim: SimTime
	var spy: Spy
	var rec: Log
	var combat: Combat
	var accessor: SpyAccessor
	var wave: EnemyWave


static func path(points: Array) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for v: Variant in points:
		out.append(float(v))
	return out


static func default_path() -> PackedFloat64Array:
	return path([-20, 950, 10, 950, 10, 980])


## One wave group: `enemy_id` x `count` at `interval` seconds, from `delay`.
static func group(enemy_id: StringName, count: int, interval: float, delay: float) -> WaveGroup:
	var g: WaveGroup = WaveGroup.new()
	g.enemy_id = enemy_id
	g.count = count
	g.spawn_interval = interval
	g.start_delay = delay
	return g


static func wave_record(groups: Array[WaveGroup], intermission: float = 2.0) -> WaveRecord:
	var w: WaveRecord = WaveRecord.new()
	w.groups = groups
	w.intermission_duration = intermission
	return w


## One grunt per wave, intermission 2.0.
static func simple_wave(intermission: float = 2.0) -> WaveRecord:
	return wave_record([group(GRUNT, 1, 0.0, 0.0)], intermission)


static func default_waves() -> Array[WaveRecord]:
	return [simple_wave(), simple_wave()]


## Builds a battle slice: real catalogue records from `DataFixtures`, a spy
## accessor, a real Combat and the EnemyWave under test.
static func make_rig(points: PackedFloat64Array, waves: Array[WaveRecord], ticks_per_second: int = 4,
		speed: float = 40.0, field_w: float = 540.0, field_h: float = 960.0) -> Rig:
	var data: Dictionary = DataFixtures.minimal()
	var grunt: Dictionary = DataFixtures.record(data, "enemy")
	grunt["move_speed"] = speed
	var other: Dictionary = grunt.duplicate(true)
	other["id"] = String(OTHER)
	other["visual_key"] = String(OTHER)
	(data["enemy"] as Array).append(other)
	var catalogue: Catalogue = DataFixtures.ready(data, "wave_rig")
	var rig: Rig = Rig.new()
	rig.sim = SimTime.new(ticks_per_second)
	rig.spy = Spy.new()
	rig.rec = Log.new()
	rig.accessor = SpyAccessor.new(catalogue, rig.spy.fatal)
	rig.accessor.spy = rig.spy
	rig.combat = Combat.new(rig.sim.to_ticks)
	var stage: StageRecord = StageRecord.new()
	stage.id = &"stage_fixture"
	stage.path_points = points
	rig.wave = EnemyWave.new(stage, waves, rig.accessor, rig.combat, rig.sim.dt, field_w, field_h,
			rig.spy.halted, rig.spy.fatal, rig.spy.dev_error, rig.sim.to_ticks)
	rig.wave.enemy_leaked.connect(rig.rec.on_leaked)
	rig.wave.enemy_killed.connect(rig.rec.on_killed)
	rig.wave.wave_cleared.connect(rig.rec.on_cleared)
	rig.wave.waves_completed.connect(rig.rec.on_completed)
	return rig


static func default_rig() -> Rig:
	return make_rig(default_path(), default_waves())


## One tick: advance, then reap.
static func step(rig: Rig) -> void:
	rig.wave.advance()
	rig.wave.reap()


static func steps(rig: Rig, n: int) -> void:
	for _i: int in n:
		step(rig)


## Kills `t` through Combat.
static func kill(rig: Rig, t: Targetable) -> void:
	rig.combat.deliver(DamageEvent.make(t, rig.combat.hp_left(t), Combat.SourceKind.TOWER, &"tower_fixture"))


static func probe(rig: Rig) -> Probe:
	var p: Probe = Probe.new()
	p.wave = rig.wave
	p.spy = rig.spy
	rig.wave.enemy_leaked.connect(p.on_leaked)
	rig.wave.enemy_killed.connect(p.on_killed)
	rig.wave.wave_cleared.connect(p.on_cleared)
	rig.wave.waves_completed.connect(p.on_completed)
	return p
