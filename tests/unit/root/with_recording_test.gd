extends GdUnitTestSuite
## ADR-0007 Decision 5 seam: recording fakes in the tick slots see the six steps of
## ADR-0004 Decision 4 in order, and the swap keeps the Builder's wiring.

const TestBattles := preload("res://tests/helpers/test_battles.gd")

const ALL_KEYS: Array[StringName] = [&"combat", &"enemy_wave", &"flow", &"tower_sim", &"hero_sim"]


func _one_tick(keys: Array[StringName]) -> Array:
	var log: Array = []
	var battle: Battle = TestBattles.with_recording(TestBattles.build(), keys, log)
	assert_object(battle).is_not_null()
	battle.flow.start_wave()
	battle.tick(battle.sim_time.dt)
	return log


func test_recording_fakes_see_the_six_steps_in_order() -> void:
	var log: Array = _one_tick(ALL_KEYS)
	assert_array(log).is_equal([
		[&"flow", &"tick"],
		[&"enemy_wave", &"advance"],
		[&"combat", &"tick_status"],
		[&"tower_sim", &"tick"],
		[&"hero_sim", &"tick"],
		[&"enemy_wave", &"reap"],
	])


func test_only_the_named_keys_record() -> void:
	var log: Array = _one_tick([&"flow", &"hero_sim"])
	assert_array(log).is_equal([[&"flow", &"tick"], [&"hero_sim", &"tick"]])


func test_swapped_battle_keeps_the_wiring() -> void:
	var log: Array = []
	var battle: Battle = TestBattles.with_recording(TestBattles.build(), ALL_KEYS, log)
	assert_object(battle).is_not_null()
	assert_array(Array(battle.emitters())).has_size(Battle.EMITTER_KEYS.size())
	assert_int(battle.enemy_wave.enemy_leaked.get_connections().size()).is_equal(1)
	assert_int(battle.flow.wave_called_early.get_connections().size()).is_equal(1)
