extends GdUnitTestSuite
## Hero GDD criteria 1, 2, 3, 6, 7, 16, 25, 26 and ADR-0010 Validation 1 to 3
## for HeroSim's two commands: result order, refusals change nothing.

const Rig := preload("res://tests/unit/hero/helpers/hero_rig.gd")
const Fakes := preload("res://tests/helpers/sim_fakes.gd")


func _pinned(left_handed: bool = false) -> Rig:
	var rig: Rig = Rig.new(left_handed)
	rig.hero.pin(Vector2(350.0, 800.0))
	rig.rec.entries.clear()
	return rig


func test_unpinned_hero_ignores_targets_and_burst_is_not_pinned() -> void:
	var rig: Rig = Rig.new()
	rig.roster.list.append(Fakes.target(1, 350.0, 800.0, 1.0))
	var before: Dictionary = rig.hero.state_fields()

	for i: int in range(100):
		rig.hero.tick()

	assert_array(rig.combat.trace).is_empty()
	assert_array(rig.spy.reads).is_empty()
	assert_dict(rig.hero.state_fields()).is_equal(before)
	assert_int(rig.hero.burst(Vector2(350.0, 780.0))).is_equal(HeroSim.BurstResult.NOT_PINNED)
	assert_int(rig.hero.pin_state()).is_equal(HeroSim.PinState.UNPINNED)
	assert_float(rig.hero.pin_target().x).is_equal(350.0)


func test_pin_results_follow_check_order_and_refusals_change_nothing() -> void:
	var rig: Rig = Rig.new()
	var before: Dictionary = rig.hero.state_fields()

	assert_int(rig.hero.pin(Vector2(NAN, 500.0))).is_equal(HeroSim.PinResult.BAD_POSITION)
	assert_int(rig.hero.pin(Vector2(500.0, INF))).is_equal(HeroSim.PinResult.BAD_POSITION)
	assert_int(rig.hero.pin(Vector2(10.0, 500.0))).is_equal(HeroSim.PinResult.OUT_OF_BOUNDS)
	assert_int(rig.hero.pin(Vector2(456.0, 850.0))).is_equal(HeroSim.PinResult.BUTTON_ZONE)
	assert_int(rig.hero.pin(Vector2(10.0, 10.0))).is_equal(HeroSim.PinResult.OUT_OF_BOUNDS)
	rig.halt.on = true
	assert_int(rig.hero.pin(Vector2(NAN, 10.0))).is_equal(HeroSim.PinResult.HALTED)

	assert_dict(rig.hero.state_fields()).is_equal(before)
	assert_array(rig.rec.entries).is_empty()
	assert_array(rig.spy.reads).is_empty()


func test_pin_zone_boundaries_for_each_hand() -> void:
	var right: PinGeometry = PinGeometry.new(Rig.new().stage, false)
	var left: PinGeometry = PinGeometry.new(Rig.new().stage, true)

	assert_int(right.is_valid(396.0, 850.0)).is_equal(HeroSim.PinResult.OK)
	assert_int(right.is_valid(397.0, 850.0)).is_equal(HeroSim.PinResult.BUTTON_ZONE)
	assert_int(right.is_valid(84.0, 850.0)).is_equal(HeroSim.PinResult.OK)
	assert_int(left.is_valid(84.0, 756.0)).is_equal(HeroSim.PinResult.OK)
	assert_int(left.is_valid(84.0, 757.0)).is_equal(HeroSim.PinResult.BUTTON_ZONE)
	assert_int(left.is_valid(456.0, 850.0)).is_equal(HeroSim.PinResult.OK)
	assert_int(right.is_valid(186.0, 740.0)).is_equal(HeroSim.PinResult.OK)
	assert_int(left.is_valid(186.0, 741.0)).is_equal(HeroSim.PinResult.BUTTON_ZONE)


func test_pin_emits_hero_pinned_after_state_is_set() -> void:
	var rig: Rig = Rig.new()
	var seen: Array[int] = []
	rig.hero.hero_pinned.connect(func(_position: Vector2) -> void:
		seen.append(rig.hero.pin_state()))

	var result: HeroSim.PinResult = rig.hero.pin(Vector2(300.0, 800.0))

	assert_int(result).is_equal(HeroSim.PinResult.OK)
	assert_array(rig.rec.entries).is_equal(["pinned:300.0,800.0"])
	assert_array(seen).is_equal([HeroSim.PinState.WALKING])


func test_walk_moves_along_the_line_without_attacking_and_pins_exactly() -> void:
	var rig: Rig = Rig.new()
	rig.roster.list.append(Fakes.target(1, 330.0, 800.0, 1.0))
	rig.hero.pin(Vector2(300.0, 800.0))

	rig.hero.tick()
	assert_float(rig.hero.position().x).is_equal(325.0)
	assert_int(rig.hero.pin_state()).is_equal(HeroSim.PinState.WALKING)
	assert_array(rig.combat.trace).is_empty()
	rig.hero.pin(Vector2(325.0, 750.0))
	rig.hero.tick()
	rig.hero.tick()
	rig.hero.tick()

	assert_int(rig.hero.pin_state()).is_equal(HeroSim.PinState.PINNED)
	assert_float(rig.hero.position().x).is_equal(325.0)
	assert_float(rig.hero.position().y).is_equal(750.0)


func test_walk_ticks_round_up_with_tolerance() -> void:
	var cases: Array[Array] = [[25.0, 1], [25.01, 2], [100.0, 4], [0.001, 1]]
	for case: Array in cases:
		var rig: Rig = Rig.new()
		var distance: float = case[0]

		rig.hero.pin(Vector2(350.0 - distance, 800.0))

		assert_int(int(rig.hero.state_fields()["walk_ticks"])).is_equal(case[1])


func test_pin_at_own_position_is_pinned_at_once_and_counts_as_pinning() -> void:
	var rig: Rig = Rig.new()

	var result: HeroSim.PinResult = rig.hero.pin(Vector2(350.0, 800.0))

	assert_int(result).is_equal(HeroSim.PinResult.OK)
	assert_int(rig.hero.pin_state()).is_equal(HeroSim.PinState.PINNED)
	assert_int(rig.hero.repins()).is_equal(0)
	assert_int(rig.hero.burst(Vector2(350.0, 780.0))).is_equal(HeroSim.BurstResult.OK)


func test_repins_count_each_ok_pin_after_the_first_with_distance() -> void:
	var rig: Rig = Rig.new()
	rig.hero.pin(Vector2(300.0, 800.0))
	assert_int(rig.hero.repins()).is_equal(0)
	rig.hero.pin(Vector2(10.0, 10.0))
	assert_int(rig.hero.repins()).is_equal(0)
	rig.hero.tick()
	rig.hero.tick()

	rig.hero.pin(Vector2(350.0, 800.0))
	assert_int(rig.hero.repins()).is_equal(1)
	rig.hero.tick()
	rig.hero.tick()
	rig.hero.pin(Vector2(350.0, 800.0))

	assert_int(rig.hero.repins()).is_equal(1)


func test_burst_results_follow_check_order() -> void:
	var rig: Rig = Rig.new()
	rig.build.on = true
	assert_int(rig.hero.burst(Vector2(NAN, 0.0))).is_equal(HeroSim.BurstResult.BUILD_PHASE)
	rig.build.on = false
	assert_int(rig.hero.burst(Vector2(NAN, 0.0))).is_equal(HeroSim.BurstResult.NOT_PINNED)
	rig.hero.pin(Vector2(350.0, 800.0))
	assert_int(rig.hero.burst(Vector2(NAN, 0.0))).is_equal(HeroSim.BurstResult.BAD_POSITION)
	assert_int(rig.hero.burst(Vector2(541.0, 800.0))).is_equal(HeroSim.BurstResult.OFF_FIELD)
	assert_int(rig.hero.burst(Vector2(350.0, 961.0))).is_equal(HeroSim.BurstResult.OFF_FIELD)
	assert_int(rig.hero.burst(Vector2(350.0, 599.0))).is_equal(HeroSim.BurstResult.OUT_OF_REACH)
	assert_int(rig.hero.burst(Vector2(350.0, 600.0))).is_equal(HeroSim.BurstResult.OK)
	assert_int(rig.hero.burst(Vector2(350.0, 700.0))).is_equal(HeroSim.BurstResult.NOT_READY)
	rig.halt.on = true
	assert_int(rig.hero.burst(Vector2(NAN, 0.0))).is_equal(HeroSim.BurstResult.HALTED)


func test_burst_refusal_changes_nothing_and_reads_only_what_came_before() -> void:
	var rig: Rig = _pinned()
	var before: Dictionary = rig.hero.state_fields()
	rig.spy.reads.clear()

	var result: HeroSim.BurstResult = rig.hero.burst(Vector2(350.0, 599.0))

	assert_int(result).is_equal(HeroSim.BurstResult.OUT_OF_REACH)
	assert_dict(rig.hero.state_fields()).is_equal(before)
	assert_array(rig.rec.entries).is_empty()
	assert_array(rig.spy.reads).is_equal(["burst_a|0|reach"])


func test_burst_ok_emits_started_with_two_telegraph_ticks_and_floors_at_one() -> void:
	var rig: Rig = _pinned()

	var result: HeroSim.BurstResult = rig.hero.burst(Vector2(350.0, 780.0))

	assert_int(result).is_equal(HeroSim.BurstResult.OK)
	assert_array(rig.rec.entries).is_equal(["burst:350.0,780.0:2"])
	assert_int(rig.hero.burst_state()).is_equal(HeroSim.BurstState.TELEGRAPHING)

	var zero: Rig = _pinned()
	zero.spy.set_value(Rig.BURST, 0, &"telegraph_duration", 0.0)
	zero.hero.burst(Vector2(350.0, 780.0))
	assert_array(zero.rec.entries).is_equal(["burst:350.0,780.0:1"])


func test_reach_is_measured_from_the_current_position_while_walking() -> void:
	var rig: Rig = Rig.new()
	rig.hero.pin(Vector2(350.0, 800.0))
	rig.hero.pin(Vector2(250.0, 800.0))
	rig.hero.tick()

	assert_float(rig.hero.position().x).is_equal(325.0)
	assert_int(rig.hero.burst(Vector2(125.0, 800.0))).is_equal(HeroSim.BurstResult.OK)


func test_latch_on_reach_or_walk_speed_read_gives_halted_and_changes_nothing() -> void:
	var rig: Rig = Rig.new()
	rig.spy.latch_key = &"walk_speed"
	var before: Dictionary = rig.hero.state_fields()
	assert_int(rig.hero.pin(Vector2(300.0, 800.0))).is_equal(HeroSim.PinResult.HALTED)
	assert_dict(rig.hero.state_fields()).is_equal(before)
	assert_array(rig.rec.entries).is_empty()

	var rig2: Rig = _pinned()
	rig2.spy.latch_key = &"telegraph_duration"
	var before2: Dictionary = rig2.hero.state_fields()
	assert_int(rig2.hero.burst(Vector2(350.0, 780.0))).is_equal(HeroSim.BurstResult.HALTED)
	assert_dict(rig2.hero.state_fields()).is_equal(before2)


func test_commands_inside_a_tick_are_fatal_and_return_halted() -> void:
	var rig: Rig = Rig.new()
	rig.between.ok = false
	var before: Dictionary = rig.hero.state_fields()

	assert_int(rig.hero.pin(Vector2(300.0, 800.0))).is_equal(HeroSim.PinResult.HALTED)
	rig.halt.on = false
	assert_int(rig.hero.burst(Vector2(300.0, 800.0))).is_equal(HeroSim.BurstResult.HALTED)

	assert_str(rig.fatal.causes[0]).contains("HeroSim.pin")
	assert_str(rig.fatal.causes[1]).contains("HeroSim.burst")
	assert_dict(rig.hero.state_fields()).is_equal(before)


func test_repin_during_telegraph_leaves_the_aim_point() -> void:
	var rig: Rig = _pinned()
	rig.hero.burst(Vector2(350.0, 780.0))

	var again: HeroSim.BurstResult = rig.hero.burst(Vector2(300.0, 800.0))
	rig.hero.pin(Vector2(300.0, 800.0))

	assert_int(again).is_equal(HeroSim.BurstResult.NOT_READY)
	assert_float(float(rig.hero.state_fields()["aim_x"])).is_equal(350.0)
	assert_float(float(rig.hero.state_fields()["aim_y"])).is_equal(780.0)


func test_never_pinned_hero_keeps_initial_fields_through_a_scripted_run() -> void:
	var rig: Rig = Rig.new()
	var initial: Dictionary = rig.hero.state_fields()
	rig.roster.list.append(Fakes.target(1, 350.0, 800.0, 1.0))

	for i: int in range(40):
		rig.hero.tick()
		rig.hero.burst(Vector2(350.0, 780.0))

	assert_dict(rig.hero.state_fields()).is_equal(initial)
	assert_str(String(rig.hero.hero_id())).is_equal("hero_a")
	assert_str(String(rig.hero.burst_id())).is_equal("burst_a")
