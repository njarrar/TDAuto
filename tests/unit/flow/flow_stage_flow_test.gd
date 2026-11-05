extends GdUnitTestSuite
## Game State & Stage Flow acceptance criteria 1 to 15 (Logic), ADR-0010
## Validation 3 for Flow, ADR-0006 Decision 6 (StageResult at the commit).
## dt is 0.25 (SimTime.new(4)); the stage has 3 lives and a 1.0 s intermission.

const Fakes := preload("res://tests/helpers/sim_fakes.gd")
const DataFixtures := preload("res://tests/helpers/data_fixtures.gd")

const P_BUILD: int = 0
const P_WAVE: int = 1
const P_INTER: int = 2
const P_PAUSED: int = 3
const P_WON: int = 4
const P_LOST: int = 5
const P_FATAL: int = 6


## One Flow with its fakes. fatal() mimics the FatalRelay: record, latch, hook.
class Rig extends RefCounted:
	var flow: Flow
	## Held here: a method Callable (sim.to_ticks) does not keep its object alive.
	var sim: SimTime
	var rec: Fakes.Recorder = Fakes.Recorder.new()
	var wave: Fakes.WaveStub = Fakes.WaveStub.new()
	var cancel: Fakes.Counter = Fakes.Counter.new()
	var halt: Fakes.Halt = Fakes.Halt.new()
	var between: Fakes.Between = Fakes.Between.new()
	var devs: Fakes.DevLog = Fakes.DevLog.new()
	var causes: Array[String] = []
	var cancel_at_phase_signal: Array[int] = []

	func fatal(cause: String) -> void:
		causes.append(cause)
		halt.on = true
		flow.enter_fatal()

	func on_phase_probe(_value: int) -> void:
		cancel_at_phase_signal.append(cancel.calls)


func _rig(lives: int = 3) -> Rig:
	var data: Dictionary = DataFixtures.stage("stage_a")
	data["starting_lives"] = lives
	var stage: StageRecord = StageRecord.from_dict(data)
	var sim: SimTime = SimTime.new(4)
	var rig: Rig = Rig.new()
	rig.sim = sim
	rig.flow = Flow.new(stage, rig.halt.is_halted, rig.between.is_between, rig.fatal,
			sim.to_ticks, sim.dt, rig.wave.start_next_wave, rig.cancel.hit, rig.devs.report,
			rig.wave.wave_index)
	rig.flow.phase_changed.connect(rig.rec.on_phase)
	rig.flow.phase_changed.connect(rig.on_phase_probe)
	rig.flow.lives_changed.connect(rig.rec.on_lives)
	rig.flow.wave_called_early.connect(rig.rec.on_called)
	return rig


func _to_intermission(rig: Rig, duration: float = 1.0) -> void:
	rig.flow.start_wave()
	rig.flow.on_wave_cleared(duration)
	rig.rec.entries.clear()


func test_build_phase_idle_ticks_then_start_twice_gives_one_wave() -> void:
	var rig: Rig = _rig()
	for i: int in range(100):
		rig.flow.tick()
	assert_array(rig.rec.entries).is_empty()
	assert_int(rig.wave.starts).is_equal(0)

	var first: Flow.StartResult = rig.flow.start_wave()
	var second: Flow.StartResult = rig.flow.start_wave()

	assert_int(first).is_equal(Flow.StartResult.OK)
	assert_int(second).is_equal(Flow.StartResult.NOT_BUILD)
	assert_array(rig.rec.entries).is_equal(["phase:%d" % P_WAVE])
	assert_int(rig.wave.starts).is_equal(1)


func test_wave_cleared_counts_down_whole_ticks_then_starts_next_wave() -> void:
	var rig: Rig = _rig()
	rig.flow.start_wave()
	rig.rec.entries.clear()

	rig.flow.on_wave_cleared(1.0)
	for i: int in range(3):
		rig.flow.tick()

	assert_array(rig.rec.entries).is_equal(["phase:%d" % P_INTER])
	assert_int(rig.wave.starts).is_equal(1)
	assert_int(rig.flow.intermission_left).is_equal(1)

	rig.flow.tick()

	assert_array(rig.rec.entries).is_equal(["phase:%d" % P_INTER, "phase:%d" % P_WAVE])
	assert_int(rig.wave.starts).is_equal(2)


func test_call_early_pays_seconds_left_once_and_second_call_is_refused() -> void:
	var rig: Rig = _rig()
	_to_intermission(rig)
	rig.flow.tick()
	rig.flow.tick()

	var first: Flow.CallResult = rig.flow.call_early()
	var second: Flow.CallResult = rig.flow.call_early()

	assert_int(first).is_equal(Flow.CallResult.OK)
	assert_int(second).is_equal(Flow.CallResult.NOT_INTERMISSION)
	assert_array(rig.rec.entries).is_equal(["called:0.5", "phase:%d" % P_WAVE])
	assert_int(rig.wave.starts).is_equal(2)


func test_call_early_in_build_wave_or_after_expiry_does_nothing() -> void:
	var rig: Rig = _rig()
	assert_int(rig.flow.call_early()).is_equal(Flow.CallResult.NOT_INTERMISSION)
	rig.flow.start_wave()
	rig.rec.entries.clear()
	assert_int(rig.flow.call_early()).is_equal(Flow.CallResult.NOT_INTERMISSION)
	rig.flow.on_wave_cleared(0.25)
	rig.flow.tick()
	rig.rec.entries.clear()
	var starts: int = rig.wave.starts

	var after_expiry: Flow.CallResult = rig.flow.call_early()

	assert_int(after_expiry).is_equal(Flow.CallResult.NOT_INTERMISSION)
	assert_array(rig.rec.entries).is_empty()
	assert_int(rig.wave.starts).is_equal(starts)


func test_zero_duration_starts_next_wave_on_next_tick_and_call_at_zero_is_ignored() -> void:
	var rig: Rig = _rig()
	rig.flow.start_wave()
	rig.flow.on_wave_cleared(0.0)
	rig.rec.entries.clear()

	var at_zero: Flow.CallResult = rig.flow.call_early()
	rig.flow.tick()

	assert_int(at_zero).is_equal(Flow.CallResult.NOTHING_LEFT)
	assert_array(rig.rec.entries).is_equal(["phase:%d" % P_WAVE])
	assert_int(rig.wave.starts).is_equal(2)


func test_waves_completed_in_last_wave_is_won() -> void:
	var rig: Rig = _rig()
	rig.flow.start_wave()
	rig.rec.entries.clear()

	rig.flow.on_waves_completed()

	assert_array(rig.rec.entries).is_equal(["phase:%d" % P_WON])
	assert_int(rig.flow.phase()).is_equal(Flow.Phase.WON)


func test_leaks_apply_lives_formula_and_lost_on_zero() -> void:
	var rig: Rig = _rig()
	rig.flow.start_wave()
	rig.rec.entries.clear()

	rig.flow.on_enemy_leaked(2)
	rig.flow.on_enemy_leaked(0)
	assert_array(rig.rec.entries).is_equal(["lives:1"])
	rig.rec.entries.clear()
	rig.flow.on_enemy_leaked(5)
	rig.flow.on_enemy_leaked(1)

	assert_array(rig.rec.entries).is_equal(["lives:0", "phase:%d" % P_LOST])
	assert_int(rig.flow.lives()).is_equal(0)


func test_leak_then_waves_completed_on_one_tick_stays_lost() -> void:
	var rig: Rig = _rig(1)
	rig.flow.start_wave()
	rig.rec.entries.clear()

	rig.flow.on_enemy_leaked(1)
	rig.flow.on_waves_completed()

	assert_array(rig.rec.entries).is_equal(["lives:0", "phase:%d" % P_LOST])
	assert_int(rig.flow.result().outcome).is_equal(Flow.Phase.LOST)
	assert_array(rig.devs.messages).is_empty()


func test_outcome_latches_and_result_is_built_before_phase_changed() -> void:
	var rig: Rig = _rig()
	rig.flow.start_wave()
	rig.flow.on_waves_completed()
	var result: StageResult = rig.flow.result()
	rig.rec.entries.clear()

	rig.flow.tick()
	rig.flow.on_wave_cleared(1.0)
	rig.flow.on_enemy_leaked(1)
	var start: Flow.StartResult = rig.flow.start_wave()
	var call: Flow.CallResult = rig.flow.call_early()
	rig.flow.pause()
	rig.flow.resume()

	assert_array(rig.rec.entries).is_empty()
	assert_int(start).is_equal(Flow.StartResult.HALTED)
	assert_int(call).is_equal(Flow.CallResult.HALTED)
	assert_object(rig.flow.result()).is_same(result)
	assert_int(result.outcome).is_equal(Flow.Phase.WON)
	assert_int(result.lives_left).is_equal(3)


func test_cancel_input_runs_before_outcome_and_pause_signals_not_on_phase_changes() -> void:
	var rig: Rig = _rig()
	rig.flow.start_wave()
	rig.flow.on_wave_cleared(1.0)
	rig.flow.tick()
	rig.flow.tick()
	rig.flow.tick()
	rig.flow.tick()
	assert_int(rig.cancel.calls).is_equal(0)
	rig.cancel_at_phase_signal.clear()

	rig.flow.pause()
	rig.flow.resume()
	rig.flow.on_waves_completed()

	# pause: cancel already called at the signal; resume: no new cancel; won: cancel called
	assert_array(rig.cancel_at_phase_signal).is_equal([1, 1, 2])


func test_enemy_leaked_outside_a_wave_follows_rule_15a() -> void:
	var rig: Rig = _rig()
	rig.flow.on_enemy_leaked(2)
	assert_array(rig.rec.entries).is_empty()
	assert_int(rig.flow.lives()).is_equal(3)
	assert_int(rig.devs.messages.size()).is_equal(1)

	_to_intermission(rig)
	rig.flow.on_enemy_leaked(2)

	assert_array(rig.rec.entries).is_equal(["lives:1"])
	assert_int(rig.devs.messages.size()).is_equal(2)


func test_wave_cleared_in_wrong_phase_is_reported_and_ignored() -> void:
	var rig: Rig = _rig()

	rig.flow.on_wave_cleared(1.0)
	rig.flow.on_waves_completed()

	assert_int(rig.flow.phase()).is_equal(Flow.Phase.BUILD)
	assert_array(rig.rec.entries).is_empty()
	assert_int(rig.devs.messages.size()).is_equal(2)


func test_pause_restores_each_live_phase_with_countdown_unchanged() -> void:
	for target_phase: int in [P_BUILD, P_WAVE, P_INTER]:
		var rig: Rig = _rig()
		if target_phase >= P_WAVE:
			rig.flow.start_wave()
		if target_phase == P_INTER:
			rig.flow.on_wave_cleared(1.0)
			rig.flow.tick()
		var left: int = rig.flow.intermission_left

		rig.flow.pause()
		for i: int in range(100):
			rig.flow.tick()
		rig.flow.call_early()
		rig.flow.start_wave()
		rig.flow.pause()
		rig.flow.resume()

		assert_int(rig.flow.phase()).is_equal(target_phase)
		assert_int(rig.flow.intermission_left).is_equal(left)


func test_fatal_keeps_first_cause_and_blocks_later_transitions() -> void:
	var rig: Rig = _rig()
	rig.flow.start_wave()
	rig.rec.entries.clear()

	rig.fatal("first")
	rig.fatal("second")
	rig.flow.tick()
	rig.flow.on_enemy_leaked(1)
	rig.flow.resume()

	assert_int(rig.flow.phase()).is_equal(Flow.Phase.FATAL)
	assert_int(rig.flow.result().outcome).is_equal(Flow.Phase.FATAL)
	assert_array(rig.rec.entries).is_equal(["phase:%d" % P_FATAL])
	assert_str(rig.causes[0]).is_equal("first")


func test_command_inside_tick_calls_fatal_names_it_and_returns_halted() -> void:
	var rig: Rig = _rig()
	_to_intermission(rig)
	rig.between.ok = false
	var left: int = rig.flow.intermission_left

	var call: Flow.CallResult = rig.flow.call_early()

	assert_int(call).is_equal(Flow.CallResult.HALTED)
	assert_int(rig.causes.size()).is_equal(1)
	assert_str(rig.causes[0]).contains("Flow.call_early")
	assert_int(rig.wave.starts).is_equal(1)
	assert_int(left).is_equal(4)


func test_start_wave_and_pause_inside_tick_are_fatal() -> void:
	var rig: Rig = _rig()
	rig.between.ok = false

	var start: Flow.StartResult = rig.flow.start_wave()

	assert_int(start).is_equal(Flow.StartResult.HALTED)
	assert_str(rig.causes[0]).contains("Flow.start_wave")
	assert_int(rig.wave.starts).is_equal(0)

	var rig2: Rig = _rig()
	rig2.between.ok = false
	rig2.flow.pause()
	assert_str(rig2.causes[0]).contains("Flow.pause")
	assert_int(rig2.flow.phase()).is_equal(Flow.Phase.FATAL)


func test_stage_result_copies_wave_index_and_damage_at_the_commit() -> void:
	var data: Dictionary = DataFixtures.stage("stage_a")
	var stage: StageRecord = StageRecord.from_dict(data)
	var sim: SimTime = SimTime.new(4)
	var halt: Fakes.Halt = Fakes.Halt.new()
	var between: Fakes.Between = Fakes.Between.new()
	var wave: Fakes.WaveStub = Fakes.WaveStub.new()
	var combat: Fakes.FakeCombat = Fakes.FakeCombat.new(sim.to_ticks)
	var fatal: Fakes.FatalLog = Fakes.FatalLog.new()
	var flow: Flow = Flow.new(stage, halt.is_halted, between.is_between, fatal.fatal,
			sim.to_ticks, sim.dt, wave.start_next_wave, Callable(), Callable(),
			wave.wave_index, combat.dealt_by_kind, combat.dealt_total)

	flow.start_wave()
	flow.on_waves_completed()

	var result: StageResult = flow.result()
	assert_int(result.last_wave_started).is_equal(1)
	assert_float(result.dealt_total).is_equal(0.0)


func test_two_flows_with_one_script_give_identical_logs() -> void:
	var logs: Array = []
	for n: int in range(2):
		var rig: Rig = _rig()
		rig.flow.start_wave()
		rig.flow.on_enemy_leaked(1)
		rig.flow.on_wave_cleared(0.5)
		rig.flow.tick()
		rig.flow.call_early()
		rig.flow.on_enemy_leaked(5)
		logs.append(rig.rec.entries.duplicate())
	assert_array(logs[0]).is_equal(logs[1])
