extends GdUnitTestSuite
## ADR-0004 Validation 2: the gate, the one tick order, the halted stop,
## between_ticks and ticks_run. Recording subclasses replace the real systems.

const TestBattles := preload("res://tests/helpers/test_battles.gd")
const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")

const ORDER: Array[String] = ["flow", "advance", "status", "tower", "hero", "reap"]


## Records every dev error.
class DevRec extends RefCounted:
	var messages: Array[String] = []

	func report(msg: String) -> void:
		messages.append(msg)


class RecFlow extends Flow:
	var log: Array[String] = []

	func _init(p_log: Array[String], b: Battle) -> void:
		super(b.stage_record, b.halted, b.between_ticks, b.relay.fatal, b.sim_time.to_ticks,
				b.sim_time.dt, b.enemy_wave.start_next_wave)
		log = p_log

	func tick() -> void:
		log.append("flow")

	func phase() -> Flow.Phase:
		return Flow.Phase.WAVE


class RecWave extends EnemyWave:
	var log: Array[String] = []
	var fatal_on_advance: Callable = Callable()

	func _init(p_log: Array[String], b: Battle, waves: Array[WaveRecord]) -> void:
		super(b.stage_record, waves, b.accessor, b.combat, b.sim_time.dt, FieldBounds.WIDTH,
				FieldBounds.HEIGHT, b.halted, b.relay.fatal, b.dev_error, b.sim_time.to_ticks)
		log = p_log

	func advance() -> void:
		log.append("advance")
		if fatal_on_advance.is_valid():
			fatal_on_advance.call("stop here")

	func reap() -> void:
		log.append("reap")


class RecCombat extends Combat:
	var log: Array[String] = []

	func _init(p_log: Array[String], b: Battle) -> void:
		super(b.sim_time.to_ticks)
		log = p_log

	func tick_status(_roster: Array[Targetable]) -> void:
		log.append("status")


class RecTower extends TowerSim:
	var log: Array[String] = []

	func _init(p_log: Array[String], b: Battle) -> void:
		super(b.stage_record, b.accessor, b.halted, b.between_ticks, b.enemy_wave.targets,
				b.sim_time.to_ticks, b.combat, b.relay.fatal, b.dev_error)
		log = p_log

	func tick() -> void:
		log.append("tower")


class RecHero extends HeroSim:
	var log: Array[String] = []

	func _init(p_log: Array[String], b: Battle) -> void:
		super(b.stage_record, &"hero_a", &"burst_a", false, b.accessor, b.halted, b.between_ticks,
				b.in_build, b.enemy_wave.targets, b.sim_time.to_ticks, b.sim_time.dt, b.combat,
				b.relay.fatal)
		log = p_log

	func tick() -> void:
		log.append("hero")


## Re-enters tick from the first leak.
class Reenter extends RefCounted:
	var battle: Battle = null
	var fired: bool = false

	func on_leaked(_cost: int) -> void:
		if fired:
			return
		fired = true
		battle.tick(battle.sim_time.dt)


## A battle whose systems are recorders, in Wave phase.
func _recording_battle(log: Array[String]) -> Battle:
	var cat: Catalogue = TestBattles.catalogue()
	var b: Battle = TestBattles.build(cat)
	var waves: Array[WaveRecord] = [cat.wave(&"wave_a")]
	b.combat = RecCombat.new(log, b)
	b.enemy_wave = RecWave.new(log, b, waves)
	b.tower_sim = RecTower.new(log, b)
	b.hero_sim = RecHero.new(log, b)
	b.flow = RecFlow.new(log, b)
	return b


func test_build_phase_runs_no_step() -> void:
	var battle: Battle = TestBattles.build()

	battle.tick(battle.sim_time.dt)

	assert_int(battle.ticks_run()).is_equal(0)


func test_wave_phase_runs_one_tick() -> void:
	var battle: Battle = TestBattles.build()
	battle.flow.start_wave()

	battle.tick(battle.sim_time.dt)
	battle.tick(battle.sim_time.dt)

	assert_int(battle.ticks_run()).is_equal(2)
	assert_int(battle.enemy_wave.wave_tick()).is_equal(2)


func test_paused_runs_no_tick_and_resume_continues() -> void:
	var battle: Battle = TestBattles.build()
	battle.flow.start_wave()
	battle.tick(battle.sim_time.dt)

	battle.flow.pause()
	for i in range(100):
		battle.tick(battle.sim_time.dt)
	assert_int(battle.ticks_run()).is_equal(1)
	assert_int(battle.enemy_wave.wave_tick()).is_equal(1)

	battle.flow.resume()
	battle.tick(battle.sim_time.dt)
	assert_int(battle.ticks_run()).is_equal(2)


func test_six_steps_run_in_the_one_order() -> void:
	var log: Array[String] = []
	var battle: Battle = _recording_battle(log)

	battle.tick(battle.sim_time.dt)

	assert_array(log).is_equal(ORDER)
	assert_int(battle.ticks_run()).is_equal(1)
	assert_bool(battle.between_ticks()).is_true()


func test_halted_in_step_two_stops_steps_three_to_six() -> void:
	var log: Array[String] = []
	var battle: Battle = _recording_battle(log)
	(battle.enemy_wave as RecWave).fatal_on_advance = battle.relay.fatal

	await assert_error(battle.tick.bind(battle.sim_time.dt)).is_push_error("stop here")

	assert_array(log).is_equal(["flow", "advance"])
	assert_bool(battle.between_ticks()).is_true()
	assert_bool(battle.halted()).is_true()


func test_wrong_dt_records_one_dev_error_and_runs_nothing() -> void:
	var battle: Battle = TestBattles.build()
	var rec: DevRec = DevRec.new()
	battle.set_dev_error_sink(rec.report)
	battle.flow.start_wave()

	battle.tick(1.0 / 30.0)

	assert_int(battle.ticks_run()).is_equal(0)
	assert_array(rec.messages).is_equal([Battle.ERR_BAD_DT])


func test_reentrant_tick_records_one_dev_error() -> void:
	var battle: Battle = TestBattles.build()
	var rec: DevRec = DevRec.new()
	battle.set_dev_error_sink(rec.report)
	var listener: Reenter = Reenter.new()
	listener.battle = battle
	battle.enemy_wave.enemy_leaked.connect(listener.on_leaked)
	battle.flow.start_wave()

	for i in range(TestBattles.MAX_TICKS):
		battle.tick(battle.sim_time.dt)
		if listener.fired:
			break

	assert_bool(listener.fired).is_true()
	assert_array(rec.messages).is_equal([Battle.ERR_REENTRANT])
	assert_bool(battle.between_ticks()).is_true()


func test_input_canceller_is_a_no_op_until_set() -> void:
	var battle: Battle = TestBattles.build()
	var rec: DevRec = DevRec.new()

	battle.cancel_input()
	battle.set_input_canceller(rec.report.bind("cancelled"))
	battle.cancel_input()

	assert_array(rec.messages).is_equal(["cancelled"])
