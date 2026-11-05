extends GdUnitTestSuite
## Hero GDD criteria 4, 5, 8, 9, 16, 18 to 24 and 28: the hero tick (walk,
## attack, cooldown, telegraph, release) and the counters.
## Trace lines: attack:<kind>:<id>:<radius>:<x>:<y>, deliver:<spawn>:<amount>:<kind>:<id>.
## Kinds: 0 TOWER, 1 HERO, 2 BURST.

const Rig := preload("res://tests/unit/hero/helpers/hero_rig.gd")
const Fakes := preload("res://tests/helpers/sim_fakes.gd")


func _hero_hits(rig: Rig) -> int:
	var count: int = 0
	for line: String in rig.combat.trace:
		if line.begins_with("deliver") and line.ends_with(":1:hero_a"):
			count += 1
	return count


func _burst_delivers(rig: Rig) -> Array[String]:
	var out: Array[String] = []
	for line: String in rig.combat.trace:
		if line.begins_with("deliver") and line.ends_with(":2:burst_a"):
			out.append(line)
	return out


func _tick(rig: Rig, count: int) -> void:
	for i: int in range(count):
		rig.hero.tick()


func test_pinned_hero_hits_the_nearest_inside_the_leash_inclusive() -> void:
	var rig: Rig = Rig.new()
	rig.pin_and_settle(350.0, 800.0)
	rig.roster.list.append(Fakes.target(1, 440.0, 800.0, 1.0))
	rig.roster.list.append(Fakes.target(2, 350.0, 890.5, 2.0))

	rig.hero.tick()

	assert_array(rig.combat.trace).is_equal([
		"attack:1:hero_a:0.0:440.0:800.0", "deliver:1:4.0:1:hero_a"])
	assert_float(rig.hero.position().x).is_equal(350.0)

	var far: Rig = Rig.new()
	far.pin_and_settle(350.0, 800.0)
	far.roster.list.append(Fakes.target(1, 440.01, 800.0, 1.0))
	far.hero.tick()
	assert_array(far.combat.trace).is_empty()


func test_eight_ticks_with_a_target_give_four_hits() -> void:
	var rig: Rig = Rig.new()
	rig.pin_and_settle(350.0, 800.0)
	rig.roster.list.append(Fakes.target(1, 400.0, 800.0, 1.0))

	_tick(rig, 8)

	assert_int(_hero_hits(rig)).is_equal(4)


func test_last_walk_tick_pins_exactly_and_attacks_on_that_tick() -> void:
	var rig: Rig = Rig.new()
	rig.roster.list.append(Fakes.target(1, 300.0, 850.0, 1.0))
	rig.hero.pin(Vector2(300.0, 800.0))

	rig.hero.tick()
	assert_int(_hero_hits(rig)).is_equal(0)
	rig.hero.tick()

	assert_int(rig.hero.pin_state()).is_equal(HeroSim.PinState.PINNED)
	assert_float(rig.hero.position().x).is_equal(300.0)
	assert_int(_hero_hits(rig)).is_equal(1)


func test_attack_timer_keeps_counting_while_walking() -> void:
	var rig: Rig = Rig.new()
	rig.pin_and_settle(350.0, 800.0)
	rig.roster.list.append(Fakes.target(1, 300.0, 850.0, 1.0))
	rig.hero.tick()
	assert_int(_hero_hits(rig)).is_equal(1)

	rig.hero.pin(Vector2(250.0, 800.0))
	_tick(rig, 3)
	assert_int(_hero_hits(rig)).is_equal(1)
	rig.hero.tick()

	assert_int(_hero_hits(rig)).is_equal(2)


func test_no_target_reads_leash_only_and_an_entrant_is_hit() -> void:
	var rig: Rig = Rig.new()
	rig.pin_and_settle(350.0, 800.0)
	rig.spy.reads.clear()

	_tick(rig, 5)

	assert_array(rig.spy.reads).is_equal([
		"hero_a|0|leash_radius", "hero_a|0|leash_radius", "hero_a|0|leash_radius",
		"hero_a|0|leash_radius", "hero_a|0|leash_radius"])
	rig.roster.list.append(Fakes.target(1, 360.0, 800.0, 1.0))
	rig.hero.tick()
	assert_int(_hero_hits(rig)).is_equal(1)


func test_attack_reads_follow_the_step_order_and_latch_stops_it() -> void:
	var rig: Rig = Rig.new()
	rig.pin_and_settle(350.0, 800.0)
	rig.roster.list.append(Fakes.target(1, 360.0, 800.0, 1.0))
	rig.spy.reads.clear()

	rig.hero.tick()

	assert_array(rig.spy.reads).is_equal([
		"hero_a|0|leash_radius", "hero_a|0|damage", "hero_a|0|attack_interval"])

	var latched: Rig = Rig.new()
	latched.pin_and_settle(350.0, 800.0)
	latched.roster.list.append(Fakes.target(1, 360.0, 800.0, 1.0))
	latched.spy.latch_key = &"attack_interval"
	latched.hero.tick()
	assert_array(latched.combat.trace).is_empty()


func test_burst_releases_on_second_tick_then_cools_for_four_ticks() -> void:
	var rig: Rig = Rig.new()
	rig.pin_and_settle(350.0, 800.0)
	rig.hero.burst(Vector2(350.0, 780.0))

	rig.hero.tick()
	assert_int(rig.hero.burst_state()).is_equal(HeroSim.BurstState.TELEGRAPHING)
	assert_array(rig.combat.trace).is_empty()
	assert_int(rig.hero.burst(Vector2(350.0, 780.0))).is_equal(HeroSim.BurstResult.NOT_READY)
	rig.hero.tick()

	assert_int(rig.hero.burst_state()).is_equal(HeroSim.BurstState.COOLING)
	assert_array(rig.combat.trace).is_equal(["attack:2:burst_a:50.0:350.0:780.0"])
	assert_int(rig.hero.bursts_hit_0()).is_equal(1)
	assert_int(rig.hero.cooldown_left()).is_equal(4)
	_tick(rig, 3)
	assert_int(rig.hero.burst(Vector2(350.0, 780.0))).is_equal(HeroSim.BurstResult.NOT_READY)
	rig.hero.tick()
	assert_int(rig.hero.burst_state()).is_equal(HeroSim.BurstState.READY)


func test_release_reads_in_order_and_each_latch_stops_the_rest() -> void:
	for latch: StringName in [&"radius", &"damage", &"cooldown"]:
		var rig: Rig = Rig.new()
		rig.pin_and_settle(350.0, 800.0)
		rig.hero.burst(Vector2(350.0, 780.0))
		rig.hero.tick()
		rig.spy.reads.clear()
		rig.spy.latch_key = latch

		rig.hero.tick()

		assert_array(rig.combat.trace).is_empty()
		assert_int(rig.hero.bursts_fired()).is_equal(0)
	var ok: Rig = Rig.new()
	ok.pin_and_settle(350.0, 800.0)
	ok.hero.burst(Vector2(350.0, 780.0))
	ok.hero.tick()
	ok.spy.reads.clear()
	ok.hero.tick()
	assert_array(ok.spy.reads).is_equal([
		"hero_a|0|leash_radius", "burst_a|0|radius", "burst_a|0|damage", "burst_a|0|cooldown"])


func test_release_hits_the_entrant_and_not_the_enemy_that_left() -> void:
	var rig: Rig = Rig.new()
	rig.pin_and_settle(350.0, 800.0)
	var leaver: Targetable = Fakes.target(1, 350.0, 780.0, 1.0)
	rig.roster.list.append(leaver)
	rig.hero.burst(Vector2(350.0, 780.0))
	rig.hero.tick()
	rig.roster.list.clear()
	rig.roster.list.append(Fakes.target(2, 360.0, 780.0, 2.0))

	rig.hero.tick()

	assert_array(_burst_delivers(rig)).is_equal(["deliver:2:105.0:2:burst_a"])


func test_counters_for_bursts_with_zero_three_and_five_victims() -> void:
	var rig: Rig = Rig.new()
	rig.pin_and_settle(350.0, 800.0)
	var kill_ids: Dictionary = {11: true, 21: true, 22: true, 23: true, 24: true, 25: true}
	rig.combat.zero_ids[26] = true
	rig.combat.on_trace = func(line: String) -> void:
		var parts: PackedStringArray = line.split(":")
		if parts[0] == "deliver" and parts[3] == "2" and kill_ids.has(parts[1].to_int()):
			rig.combat.dead_ids[parts[1].to_int()] = true
	var rounds: Array[Array] = [[], [11, 12, 13], [21, 22, 23, 24, 25, 26]]

	for round_ids: Array in rounds:
		rig.roster.list.clear()
		for spawn_id: int in round_ids:
			rig.roster.list.append(Fakes.target(spawn_id, 350.0 + float(spawn_id % 10), 780.0, 1.0))
		assert_int(rig.hero.burst(Vector2(350.0, 780.0))).is_equal(HeroSim.BurstResult.OK)
		_tick(rig, 6)

	assert_int(rig.hero.bursts_fired()).is_equal(3)
	assert_int(rig.hero.bursts_hit_0()).is_equal(1)
	assert_int(rig.hero.bursts_hit_3()).is_equal(2)
	assert_int(rig.hero.bursts_hit_5()).is_equal(1)
	assert_int(rig.hero.burst_victims()).is_equal(8)
	assert_int(rig.hero.burst_kills()).is_equal(6)
	assert_array(Array(rig.hero.kills_per_burst())).is_equal([0, 1, 5])
	assert_array(Array(rig.hero.kills_on_hit_3())).is_equal([1, 5])
	assert_array(Array(rig.hero.best_victims())).is_equal([0, 3, 6])


func test_counter_getters_return_copies() -> void:
	var rig: Rig = Rig.new()
	rig.pin_and_settle(350.0, 800.0)
	rig.hero.burst(Vector2(350.0, 780.0))
	_tick(rig, 2)

	var copy: PackedInt32Array = rig.hero.kills_per_burst()
	copy.append(99)

	assert_int(rig.hero.kills_per_burst().size()).is_equal(1)


func test_halted_tick_does_nothing_and_walk_resumes_exactly_after_unhalt() -> void:
	var rig: Rig = Rig.new()
	rig.hero.pin(Vector2(250.0, 800.0))
	rig.hero.tick()
	var before: Dictionary = rig.hero.state_fields()
	rig.halt.on = true

	_tick(rig, 10)

	assert_dict(rig.hero.state_fields()).is_equal(before)
	rig.halt.on = false
	rig.hero.tick()
	assert_float(rig.hero.position().x).is_equal(300.0)


func test_two_runs_of_one_script_with_and_without_listeners_match() -> void:
	var a: Rig = Rig.new()
	var b: Rig = Rig.new()
	b.hero.hero_pinned.disconnect(b.rec.on_pinned)
	b.hero.burst_started.disconnect(b.rec.on_burst)

	for rig: Rig in [a, b]:
		rig.roster.list.append(Fakes.target(1, 300.0, 790.0, 1.0))
		rig.hero.pin(Vector2(300.0, 800.0))
		_tick(rig, 3)
		rig.hero.burst(Vector2(300.0, 790.0))
		_tick(rig, 8)

	assert_dict(a.hero.state_fields()).is_equal(b.hero.state_fields())
	assert_array(a.combat.trace).is_equal(b.combat.trace)
