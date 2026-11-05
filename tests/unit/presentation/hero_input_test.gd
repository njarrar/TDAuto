extends GdUnitTestSuite
## HeroInput on a headless battle's resolver (Hero Rules 11 to 15, ADR-0010 Validation).

const TestBattles := preload("res://tests/helpers/test_battles.gd")
const Runner := preload("res://tests/helpers/battle_runner.gd")
const Fakes := preload("res://tests/helpers/fakes.gd")
const BUTTON: Vector2 = Vector2(456.0, 888.0)

var _battle: Battle
var _hi: HeroInput
var _halt: Fakes.Halted
var _errs: Fakes.DevErrors


func before_test() -> void:
	_battle = TestBattles.build()
	_halt = Fakes.Halted.new()
	_errs = Fakes.DevErrors.new()
	_hi = HeroInput.new()
	var ok: bool = _hi.attach(_battle.resolver, _battle.hero_sim, _battle.accessor, _halt.halted,
			_battle.in_build, false, _battle.stage_record, BUTTON, _errs.report)
	assert_bool(ok).is_true()
	var r: InputResolver = _battle.resolver
	r.pressed.connect(_hi._on_pressed)
	r.drag_started.connect(_hi._on_drag_started)
	r.drag_moved.connect(_hi._on_drag_moved)
	r.drag_ended.connect(_hi._on_drag_ended)
	r.drag_cancelled.connect(_hi._on_drag_cancelled)
	r.became_idle.connect(_hi._on_became_idle)


func after_test() -> void:
	_hi.detach()


func _pin_and_start() -> void:
	_battle.hero_sim.pin(Vector2(270.0, 480.0))
	_battle.flow.start_wave()
	Runner.run(_battle, 100)
	_hi.update()


func _drag(from: Vector2, via: Array[Vector2], to: Vector2) -> void:
	var r: InputResolver = _battle.resolver
	r.press(0, from)
	for p: Vector2 in via:
		r.move(0, p)
	r.move(0, to)
	r.release(0, to)


func test_registers_three_discs_and_update_moves_hero_disc() -> void:
	var hero_pos: Vector2 = _battle.hero_sim.position()
	assert_bool(_battle.resolver.centre_of(_hi.hero_disc_id()) == hero_pos).is_true()
	_pin_and_start()
	assert_bool(_battle.resolver.centre_of(_hi.hero_disc_id()) == _battle.hero_sim.position()).is_true()


func test_hero_drag_issues_pin_at_clamped_finger() -> void:
	var start: Vector2 = _battle.hero_sim.position()
	_drag(start, [start + Vector2(-20.0, -20.0)], Vector2(270.0, 480.0))
	assert_int(_battle.hero_sim.pin_state()).is_equal(HeroSim.PinState.WALKING)
	var t: Vector2 = _battle.hero_sim.pin_target()
	assert_float(t.x).is_equal_approx(270.0, 0.01)
	assert_float(t.y).is_equal_approx(480.0, 0.01)
	assert_int(_hi.aim_state()).is_equal(HeroInput.AimState.NONE)
	assert_array(_errs.messages()).is_empty()


func test_press_on_button_is_dead_in_build_and_when_unpinned() -> void:
	_drag(BUTTON, [BUTTON + Vector2(0.0, -100.0)], BUTTON + Vector2(-100.0, -300.0))
	assert_int(_battle.hero_sim.bursts_fired()).is_equal(0)
	assert_int(_battle.hero_sim.burst_state()).is_equal(HeroSim.BurstState.READY)
	assert_int(_hi.aim_state()).is_equal(HeroInput.AimState.NONE)


func test_live_aim_releases_a_burst() -> void:
	_pin_and_start()
	var finger: Vector2 = Vector2(270.0, 650.0)
	_drag(BUTTON, [BUTTON + Vector2(-100.0, -100.0)], finger)
	assert_int(_battle.hero_sim.burst_state()).is_equal(HeroSim.BurstState.TELEGRAPHING)
	var aim: Vector2 = _hi.last_aim_fired()
	assert_float(aim.x).is_equal_approx(270.0, 0.01)
	assert_float(aim.y).is_equal_approx(550.0, 0.01)
	assert_array(_errs.messages()).is_empty()


func test_release_inside_cancel_ring_cancels() -> void:
	_pin_and_start()
	_drag(BUTTON, [], BUTTON + Vector2(-55.0, 0.0))
	assert_int(_battle.hero_sim.bursts_fired()).is_equal(0)
	assert_int(_battle.hero_sim.burst_state()).is_equal(HeroSim.BurstState.READY)


func test_hysteresis_live_between_48_and_64_then_cancel_at_48() -> void:
	_pin_and_start()
	var r: InputResolver = _battle.resolver
	r.press(0, BUTTON)
	r.move(0, BUTTON + Vector2(-70.0, 0.0))
	assert_int(_hi.aim_state()).is_equal(HeroInput.AimState.LIVE)
	r.move(0, BUTTON + Vector2(-55.0, 0.0))
	assert_int(_hi.aim_state()).is_equal(HeroInput.AimState.LIVE)
	r.move(0, BUTTON + Vector2(-48.0, 0.0))
	assert_int(_hi.aim_state()).is_equal(HeroInput.AimState.CANCELLING)
	r.move(0, BUTTON + Vector2(-55.0, 0.0))
	assert_int(_hi.aim_state()).is_equal(HeroInput.AimState.CANCELLING)
	r.release(0, BUTTON + Vector2(-55.0, 0.0))
	assert_int(_battle.hero_sim.bursts_fired()).is_equal(0)


func test_aim_clamped_to_reach_minus_margin() -> void:
	_pin_and_start()
	var reach: float = _battle.accessor.stat_float(ReadContext.make(_battle.hero_sim.burst_id(), 0), StatKeys.REACH)
	var r: InputResolver = _battle.resolver
	r.press(0, BUTTON)
	r.move(0, Vector2(100.0, 800.0))
	r.move(0, Vector2(60.0, 760.0))
	var d: float = _hi.aim_point().distance_to(_battle.hero_sim.position())
	assert_bool(d <= reach - HeroInput.REACH_MARGIN + 0.0001).is_true()
	r.cancel()
	assert_int(_hi.aim_state()).is_equal(HeroInput.AimState.NONE)
	assert_int(_battle.hero_sim.bursts_fired()).is_equal(0)


func test_drag_cancelled_never_issues_a_command() -> void:
	_pin_and_start()
	var r: InputResolver = _battle.resolver
	r.press(0, BUTTON)
	r.move(0, Vector2(270.0, 650.0))
	r.cancel()
	assert_int(_battle.hero_sim.burst_state()).is_equal(HeroSim.BurstState.READY)
	assert_int(_hi.aim_state()).is_equal(HeroInput.AimState.NONE)


func test_halted_ends_the_aim() -> void:
	_pin_and_start()
	var r: InputResolver = _battle.resolver
	r.press(0, BUTTON)
	r.move(0, Vector2(270.0, 650.0))
	_halt.value = true
	_hi.update()
	assert_int(_hi.aim_state()).is_equal(HeroInput.AimState.NONE)


func test_cooldown_digit_after_burst() -> void:
	_pin_and_start()
	_drag(BUTTON, [BUTTON + Vector2(-100.0, -100.0)], Vector2(270.0, 650.0))
	Runner.run(_battle, 30)
	_hi.update()
	assert_int(_hi.cooldown_digit()).is_greater(0)
