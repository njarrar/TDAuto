extends GdUnitTestSuite
## EnemyWave wave control and schedule: Enemy & Wave Acceptance 23 to 27,
## 30 to 41, 49, 50 and 56, with ADR-0009 Validation 10.

const WaveFixtures := preload("res://tests/helpers/wave_fixtures.gd")


## A path long enough that nothing leaks in 150 ticks at 1/60 s.
func _long_path() -> PackedFloat64Array:
	return WaveFixtures.path([-20, 950, 5000, 950])


func _spawn_ticks(rig: WaveFixtures.Rig, ticks: int) -> Array[int]:
	var out: Array[int] = []
	var seen: int = 0
	rig.wave.start_next_wave()
	for n: int in ticks:
		WaveFixtures.step(rig)
		var now: int = rig.wave.roster().size()
		for _k: int in range(seen, now):
			out.append(n)
		seen = now
	return out


func _group_wave(enemy_id: StringName, count: int, interval: float, delay: float) -> Array[WaveRecord]:
	return [WaveFixtures.wave_record([WaveFixtures.group(enemy_id, count, interval, delay)])]


# Acceptance 24

func test_nothing_happens_before_a_start() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()

	WaveFixtures.steps(rig, 100)

	assert_array(rig.rec.lines).is_empty()
	assert_int(rig.wave.wave_index()).is_equal(0)
	assert_int(int(rig.wave.wave_state())).is_equal(int(EnemyWave.WaveState.WAITING))


# Acceptance 33, 34

func test_start_commits_at_once_and_the_first_tick_spawns() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()

	rig.wave.start_next_wave()

	assert_int(int(rig.wave.wave_state())).is_equal(int(EnemyWave.WaveState.ACTIVE))
	assert_int(rig.wave.wave_tick()).is_equal(0)
	assert_int(rig.wave.wave_index()).is_equal(1)
	assert_int(rig.wave.roster().size()).is_equal(0)
	WaveFixtures.step(rig)
	assert_int(rig.wave.roster().size()).is_equal(1)
	assert_int(rig.wave.wave_tick()).is_equal(1)


# Acceptance 35, 36

func test_a_start_during_an_active_wave_is_ignored_with_one_error() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()

	rig.wave.start_next_wave()

	assert_int(rig.spy.dev_errors.size()).is_equal(1)
	assert_int(rig.wave.wave_index()).is_equal(1)
	assert_int(int(rig.wave.wave_state())).is_equal(int(EnemyWave.WaveState.ACTIVE))


func test_a_start_after_the_last_wave_is_ignored_with_one_error() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()
	WaveFixtures.steps(rig, 6)
	rig.wave.start_next_wave()
	WaveFixtures.steps(rig, 6)
	assert_int(int(rig.wave.wave_state())).is_equal(int(EnemyWave.WaveState.FINISHED))

	rig.wave.start_next_wave()

	assert_int(rig.spy.dev_errors.size()).is_equal(1)
	assert_int(rig.wave.wave_index()).is_equal(2)
	assert_int(int(rig.wave.wave_state())).is_equal(int(EnemyWave.WaveState.FINISHED))


func test_a_start_with_no_waves_is_a_development_error() -> void:
	var none: Array[WaveRecord] = []
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(WaveFixtures.default_path(), none)

	rig.wave.start_next_wave()

	assert_int(rig.spy.dev_errors.size()).is_equal(1)
	assert_int(rig.wave.wave_index()).is_equal(0)


# Acceptance 23, 25, 26

func test_a_wave_with_one_enemy_and_no_kills_clears_after_its_leak() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()

	WaveFixtures.steps(rig, 5)
	assert_array(rig.rec.lines).is_empty()
	WaveFixtures.step(rig)

	assert_array(rig.rec.lines).contains_exactly(["leaked(1)", "cleared(2.0)"])


func test_nothing_is_emitted_after_a_clear_or_after_finishing() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()
	WaveFixtures.steps(rig, 6)
	var after_first: int = rig.rec.lines.size()

	WaveFixtures.steps(rig, 100)
	assert_int(rig.rec.lines.size()).is_equal(after_first)

	rig.wave.start_next_wave()
	WaveFixtures.steps(rig, 6)
	var after_last: int = rig.rec.lines.size()
	assert_str(rig.rec.lines[after_last - 1]).is_equal("completed")
	WaveFixtures.steps(rig, 100)
	assert_int(rig.rec.lines.size()).is_equal(after_last)


# Acceptance 27

func test_an_empty_roster_between_members_does_not_clear_the_wave() -> void:
	var waves: Array[WaveRecord] = [
		WaveFixtures.wave_record([
			WaveFixtures.group(WaveFixtures.GRUNT, 1, 0.0, 0.0),
			WaveFixtures.group(WaveFixtures.GRUNT, 1, 0.0, 2.0),
		]),
		WaveFixtures.simple_wave(),
	]
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(WaveFixtures.default_path(), waves)
	rig.wave.start_next_wave()
	rig.wave.advance()
	WaveFixtures.kill(rig, rig.wave.roster()[0])
	rig.wave.reap()
	assert_array(rig.rec.lines).contains_exactly(["killed(4)"])

	for _n: int in 12:
		WaveFixtures.step(rig)
	assert_array(rig.rec.lines).contains_exactly(["killed(4)"])
	WaveFixtures.step(rig)

	assert_array(rig.rec.lines).contains_exactly(["killed(4)", "leaked(1)", "cleared(2.0)"])


# Acceptance 30, 31

func test_state_is_committed_before_the_clear_signals() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	var probe: WaveFixtures.Probe = WaveFixtures.probe(rig)
	rig.wave.start_next_wave()
	WaveFixtures.steps(rig, 6)

	assert_array(probe.states_at_clear).contains_exactly([int(EnemyWave.WaveState.WAITING)])
	assert_array(probe.index_at_clear).contains_exactly([1])

	rig.wave.start_next_wave()
	WaveFixtures.steps(rig, 6)

	assert_array(probe.states_at_completed).contains_exactly([int(EnemyWave.WaveState.FINISHED)])


# Acceptance 32

func test_each_position_emits_its_own_intermission_then_completion() -> void:
	var waves: Array[WaveRecord] = [
		WaveFixtures.simple_wave(2.0), WaveFixtures.simple_wave(3.0), WaveFixtures.simple_wave(2.0),
	]
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(WaveFixtures.default_path(), waves)

	for _w: int in 3:
		rig.wave.start_next_wave()
		WaveFixtures.steps(rig, 6)

	var clears: Array[String] = []
	for line: String in rig.rec.lines:
		if line.begins_with("cleared") or line == "completed":
			clears.append(line)
	assert_array(clears).contains_exactly(["cleared(2.0)", "cleared(3.0)", "completed"])


# Acceptance 37, 39

func test_to_ticks_values() -> void:
	var fine: SimTime = SimTime.new(60)
	var coarse: SimTime = SimTime.new(4)

	assert_int(fine.to_ticks(0.9)).is_equal(54)
	assert_int(fine.to_ticks(5.0)).is_equal(300)
	assert_int(fine.to_ticks(1.0 / 60.0)).is_equal(1)
	assert_int(fine.to_ticks(0.0)).is_equal(0)
	assert_int(coarse.to_ticks(0.125)).is_equal(1)


# Acceptance 38

func test_spawn_ticks_follow_the_absolute_schedule() -> void:
	var a: WaveFixtures.Rig = WaveFixtures.make_rig(_long_path(), _group_wave(WaveFixtures.GRUNT, 3, 0.9, 0.0), 60)
	assert_array(_spawn_ticks(a, 120)).contains_exactly([0, 54, 108])

	var b: WaveFixtures.Rig = WaveFixtures.make_rig(_long_path(), _group_wave(WaveFixtures.GRUNT, 4, 0.1, 0.0), 60)
	var ticks_b: Array[int] = _spawn_ticks(b, 30)
	assert_int(ticks_b[3]).is_equal(18)

	var c: WaveFixtures.Rig = WaveFixtures.make_rig(_long_path(), _group_wave(WaveFixtures.GRUNT, 4, 0.125, 0.0), 60)
	assert_array(_spawn_ticks(c, 30)).contains_exactly([0, 8, 15, 23])


# Acceptance 40

func test_groups_spawn_in_authored_order_members_ascending() -> void:
	var waves: Array[WaveRecord] = [WaveFixtures.wave_record([
		WaveFixtures.group(WaveFixtures.OTHER, 1, 0.0, 0.5),
		WaveFixtures.group(WaveFixtures.GRUNT, 2, 0.5, 0.0),
	])]
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(_long_path(), waves)
	rig.wave.start_next_wave()

	WaveFixtures.steps(rig, 2)
	assert_int(rig.wave.roster().size()).is_equal(1)
	assert_str(String((rig.wave.roster()[0] as Enemy).def_id)).is_equal("enemy_grunt")
	WaveFixtures.step(rig)

	assert_int(rig.wave.roster().size()).is_equal(3)
	assert_str(String((rig.wave.roster()[1] as Enemy).def_id)).is_equal("enemy_b")
	assert_str(String((rig.wave.roster()[2] as Enemy).def_id)).is_equal("enemy_grunt")
	assert_int(rig.wave.roster()[1].spawn_id).is_equal(1)
	assert_int(rig.wave.roster()[2].spawn_id).is_equal(2)


# Acceptance 41

func test_spawn_ids_continue_across_waves() -> void:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()
	WaveFixtures.steps(rig, 6)

	rig.wave.start_next_wave()
	rig.wave.advance()

	assert_int(rig.wave.roster()[0].spawn_id).is_equal(1)


# Acceptance 50

func test_spawn_interval_is_unused_for_a_single_member() -> void:
	var waves: Array[WaveRecord] = [
		WaveFixtures.wave_record([WaveFixtures.group(WaveFixtures.GRUNT, 1, 99.0, 0.0)]),
		WaveFixtures.simple_wave(),
	]
	var rig: WaveFixtures.Rig = WaveFixtures.make_rig(WaveFixtures.default_path(), waves)
	rig.wave.start_next_wave()

	WaveFixtures.steps(rig, 6)

	assert_array(rig.rec.lines).contains_exactly(["leaked(1)", "cleared(2.0)"])


# Acceptance 56

func _scripted_log() -> Array[String]:
	var rig: WaveFixtures.Rig = WaveFixtures.default_rig()
	rig.wave.start_next_wave()
	WaveFixtures.steps(rig, 6)
	rig.wave.start_next_wave()
	rig.wave.advance()
	var out: Array[String] = rig.rec.lines.duplicate()
	out.append("id%d" % rig.wave.roster()[0].spawn_id)
	WaveFixtures.steps(rig, 6)
	out.append_array(rig.rec.lines)
	return out


func test_a_new_battle_replays_identically() -> void:
	assert_array(_scripted_log()).contains_exactly(_scripted_log())
