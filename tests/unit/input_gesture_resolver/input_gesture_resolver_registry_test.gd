extends GdUnitTestSuite
## Input GDD acceptance criteria 19 to 26 (validation, registry, determinism), headless.

const Rig := preload("res://tests/unit/input_gesture_resolver/helpers/rig.gd")


func _check(g: Rig, expected: Array[String]) -> void:
	assert_str(g.joined()).is_equal(" | ".join(PackedStringArray(expected)))


func test_c19_validate_accepts_and_rejects() -> void:
	assert_bool(InputResolver.validate(8.0, 28.0)).is_true()
	assert_bool(InputResolver.validate(30.0, 34.0)).is_true()
	assert_bool(InputResolver.validate(15.0, 16.0)).is_true()
	assert_bool(InputResolver.validate(7.0, 28.0)).is_false()
	assert_bool(InputResolver.validate(31.0, 34.0)).is_false()
	assert_bool(InputResolver.validate(15.0, 15.0)).is_false()
	assert_bool(InputResolver.validate(15.0, 15.99)).is_false()
	assert_bool(InputResolver.validate(15.0, 35.0)).is_false()
	assert_bool(InputResolver.validate(NAN, 28.0)).is_false()
	assert_bool(InputResolver.validate(15.0, INF)).is_false()


func test_c19_create_returns_null_for_invalid_and_object_for_valid() -> void:
	assert_object(InputResolver.create(7.0, 28.0)).is_null()
	assert_object(InputResolver.create(31.0, 34.0)).is_null()
	assert_object(InputResolver.create(15.0, 15.0)).is_null()
	assert_object(InputResolver.create(15.0, 15.99)).is_null()
	assert_object(InputResolver.create(15.0, 35.0)).is_null()
	assert_object(InputResolver.create(NAN, 28.0)).is_null()
	assert_object(InputResolver.create(15.0, 28.0)).is_not_null()


func test_c19_register_rejects_bad_discs_with_reports() -> void:
	var g: Rig = Rig.new()
	var tap: InputResolver.Accepts = InputResolver.Accepts.TAP
	var spot: Vector2 = Vector2(100.0, 100.0)
	assert_int(g.r.register(spot, 0.0, tap, 200)).is_equal(InputResolver.NONE)
	assert_int(g.r.register(spot, -1.0, tap, 200)).is_equal(InputResolver.NONE)
	assert_int(g.r.register(spot, NAN, tap, 200)).is_equal(InputResolver.NONE)
	assert_int(g.r.register(spot, INF, tap, 200)).is_equal(InputResolver.NONE)
	assert_int(g.r.register(Vector2(NAN, 100.0), 36.0, tap, 200)).is_equal(InputResolver.NONE)
	assert_int(g.r.register(spot, 36.0, InputResolver.Accepts.DRAG, 200, true)).is_equal(InputResolver.NONE)
	assert_int(g.r.reports.size()).is_equal(6)
	assert_int(g.r.target_count()).is_equal(0)
	g.tap_at(spot)
	_check(g, ["pressed(NONE,NONE)", "ground_tapped", "became_idle"])


func test_c20_unknown_id_is_reported_noop() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.r.set_centre(999, Vector2.ZERO)
	g.r.set_enabled(999, false)
	g.r.unregister(999)
	assert_int(g.r.reports.size()).is_equal(3)
	g.tap_at(Rig.T_POS)
	_check(g, ["pressed(T,NONE)", "tapped(T)", "became_idle"])


func test_c21_non_finite_press_is_dropped_with_report() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Vector2(NAN, 100.0))
	_check(g, [])
	assert_int(g.r.reports.size()).is_equal(1)
	assert_int(g.r.state()).is_equal(InputResolver.State.IDLE)


func test_c21_non_finite_move_is_dropped() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.move(0, Vector2(INF, 100.0))
	g.r.release(0, Rig.H_POS)
	_check(g, ["pressed(NONE,H)", "became_idle"])
	assert_int(g.r.reports.size()).is_equal(1)


func test_c21_non_finite_set_centre_keeps_old_centre() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.set_centre(g.h, Vector2(NAN, 0.0))
	assert_int(g.r.reports.size()).is_equal(1)
	g.r.press(0, Rig.H_POS)
	_check(g, ["pressed(NONE,H)"])


func test_c22_idle_ignores_move_and_release() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.move(0, Rig.H_POS)
	g.r.release(0, Rig.H_POS)
	_check(g, [])


func test_c23_first_id_is_one() -> void:
	var g: Rig = Rig.new()
	assert_int(g.add_tower()).is_equal(1)


func test_c23_two_resolvers_give_identical_logs() -> void:
	var a: Rig = Rig.new()
	var b: Rig = Rig.new()
	for g: Rig in [a, b]:
		g.add_slot()
		g.add_hero(Rig.S_POS)
		g.r.press(0, Rig.S_POS)
		g.r.move(0, Vector2(298.0, 600.0))
		g.r.move(0, Vector2(310.0, 610.0))
		g.r.release(0, Vector2(330.0, 630.0))
	assert_str(a.joined()).is_equal(b.joined())
	assert_array(Array(a.l.pos_log.map(func(v: PackedVector2Array) -> Array: return Array(v)))).is_equal(
		Array(b.l.pos_log.map(func(v: PackedVector2Array) -> Array: return Array(v))))


func test_c24_ids_never_reused() -> void:
	var g: Rig = Rig.new()
	var old_id: int = g.add_tower()
	g.r.unregister(old_id)
	var new_id: int = g.add_slot()
	assert_bool(new_id != old_id).is_true()
	g.tap_at(Rig.T_POS)
	_check(g, ["pressed(NONE,NONE)", "ground_tapped", "became_idle"])
	assert_int(g.r.reports.size()).is_equal(0)


func test_c25_disabled_target_is_skipped() -> void:
	var g: Rig = Rig.new()
	g.add_slot()
	g.r.set_enabled(g.s, false)
	g.tap_at(Rig.S_POS)
	_check(g, ["pressed(NONE,NONE)", "ground_tapped", "became_idle"])
	g.r.set_enabled(g.s, true)
	g.tap_at(Rig.S_POS)
	assert_str(g.joined()).is_equal(" | ".join(PackedStringArray([
		"pressed(NONE,NONE)", "ground_tapped", "became_idle",
		"pressed(S,NONE)", "tapped(S)", "became_idle"])))


func test_c26_disable_mid_gesture_still_taps() -> void:
	var g: Rig = Rig.new()
	g.add_slot()
	g.r.press(0, Rig.S_POS)
	g.r.set_enabled(g.s, false)
	g.r.release(0, Rig.S_POS)
	_check(g, ["pressed(S,NONE)", "tapped(S)", "became_idle"])


func test_c26_move_centre_mid_gesture_keeps_frozen_disc() -> void:
	var g: Rig = Rig.new()
	g.add_slot()
	g.r.press(0, Rig.S_POS)
	g.r.set_centre(g.s, Vector2.ZERO)
	g.r.release(0, Rig.S_POS)
	_check(g, ["pressed(S,NONE)", "tapped(S)", "became_idle"])


func test_c26_unregister_mid_drag_keeps_signals() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.move(0, Vector2(120.0, 100.0))
	g.r.unregister(g.h)
	g.r.move(0, Vector2(125.0, 100.0))
	g.r.release(0, Vector2(125.0, 100.0))
	_check(g, ["pressed(NONE,H)", "drag_started(H)", "drag_moved(H)", "drag_ended(H)", "became_idle"])


func test_c26_new_target_under_finger_is_not_seen() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.r.press(0, Rig.T_POS)
	g.add_target("N", Rig.T_POS, 36.0, InputResolver.Accepts.TAP, 900)
	g.r.release(0, Rig.T_POS)
	_check(g, ["pressed(T,NONE)", "tapped(T)", "became_idle"])
