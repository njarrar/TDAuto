extends GdUnitTestSuite
## Input criteria 28 to 33 (burst, arc, formulas, tie-break) and GestureRecord values (ADR-0008 V3).

const Rig := preload("res://tests/unit/input_gesture_resolver/helpers/rig.gd")
const Listener := preload("res://tests/unit/input_gesture_resolver/helpers/recording_listener.gd")


func _check(g: Rig, expected: Array[String]) -> void:
	assert_str(g.joined()).is_equal(" | ".join(PackedStringArray(expected)))


func _along(p: Vector2, n: float) -> Vector2:
	return Vector2(p.x + n, p.y)


func test_c28_burst_tap_reaches_sink_only() -> void:
	var g: Rig = Rig.new()
	g.add_slot()
	g.r.set_centre(g.s, Rig.B_POS)
	g.add_button()
	g.tap_at(Rig.B_POS)
	_check(g, ["pressed(Z,B)", "tapped(Z)", "became_idle"])


func test_c28_burst_drag_uses_drag_slop() -> void:
	var g: Rig = Rig.new()
	g.add_slot()
	g.r.set_centre(g.s, Rig.B_POS)
	g.add_button()
	g.r.press(0, Rig.B_POS)
	g.r.move(0, _along(Rig.B_POS, 15.0))
	g.r.release(0, _along(Rig.B_POS, 15.0))
	_check(g, ["pressed(Z,B)", "drag_started(B)", "drag_ended(B)", "became_idle"])


func test_c28_hero_outranks_button() -> void:
	var g: Rig = Rig.new()
	g.add_button()
	g.add_hero(Vector2(440.0, 820.0))
	var p: Vector2 = Vector2(440.0, 840.0)
	g.r.press(0, p)
	g.r.move(0, _along(p, 15.0))
	g.r.release(0, _along(p, 15.0))
	_check(g, ["pressed(Z,H)", "drag_started(H)", "drag_ended(H)", "became_idle"])


func _arc_rig() -> Rig:
	var g: Rig = Rig.new()
	g.add_arc_disc()
	g.add_backdrop()
	g.add_tower()
	g.add_hero(Rig.T_POS)
	return g


func test_c29_arc_press_on_disc() -> void:
	var g: Rig = _arc_rig()
	g.tap_at(Vector2(270.0, 560.0))
	_check(g, ["pressed(A,NONE)", "tapped(A)", "became_idle"])


func test_c29_arc_press_on_tower_hits_backdrop() -> void:
	var g: Rig = _arc_rig()
	g.tap_at(Vector2(270.0, 470.0))
	_check(g, ["pressed(K,H)", "tapped(K)", "became_idle"])


func test_c29_arc_press_on_ground_hits_backdrop() -> void:
	var g: Rig = _arc_rig()
	g.tap_at(Rig.GROUND)
	_check(g, ["pressed(K,NONE)", "tapped(K)", "became_idle"])


func test_c29_arc_overlap_press_drags_hero_with_tap_slop() -> void:
	var g: Rig = _arc_rig()
	var p: Vector2 = Vector2(270.0, 505.0)
	g.r.press(0, p)
	g.r.move(0, _along(p, 28.0))
	_check(g, ["pressed(A,H)", "drag_started(H)"])


func test_c30_hit_boundary() -> void:
	var cases: Array[Vector2] = [Vector2(306.0, 480.0), Vector2(307.0, 480.0),
		Vector2(299.0, 500.0), Vector2(300.0, 500.0)]
	var hits: Array[bool] = [true, false, true, false]
	for i: int in range(cases.size()):
		var g: Rig = Rig.new()
		g.add_tower()
		g.tap_at(cases[i])
		if hits[i]:
			_check(g, ["pressed(T,NONE)", "tapped(T)", "became_idle"])
		else:
			_check(g, ["pressed(NONE,NONE)", "ground_tapped", "became_idle"])


func test_c32_priority_beats_distance() -> void:
	var g: Rig = Rig.new()
	g.add_arc_disc()
	g.add_tower()
	g.r.press(0, Vector2(270.0, 505.0))
	_check(g, ["pressed(A,NONE)"])
	var rec: GestureRecord = g.r.last_gesture()
	assert_int(rec.tap_rule).is_equal(GestureRecord.WinRule.PRIORITY)
	assert_int(rec.tap_candidates).is_equal(2)


func test_c32_distance_beats_order() -> void:
	var g: Rig = Rig.new()
	g.add_target("O", Vector2(270.0, 530.0), 36.0, InputResolver.Accepts.TAP, 200)
	g.add_tower()
	g.r.press(0, Vector2(270.0, 500.0))
	_check(g, ["pressed(T,NONE)"])
	assert_int(g.r.last_gesture().tap_rule).is_equal(GestureRecord.WinRule.DISTANCE)


func test_c32_lower_id_wins_exact_tie() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.add_target("O", Rig.T_POS, 36.0, InputResolver.Accepts.TAP, 200)
	g.r.press(0, Rig.T_POS)
	_check(g, ["pressed(T,NONE)"])
	assert_int(g.r.last_gesture().tap_rule).is_equal(GestureRecord.WinRule.ID)


func test_c33_target_ok_integer_formula() -> void:
	assert_bool(InputResolver.target_ok(36.0, 360.0)).is_true()
	assert_bool(InputResolver.target_ok(48.0, 360.0)).is_true()
	assert_bool(InputResolver.target_ok(35.0, 360.0)).is_false()
	assert_bool(InputResolver.target_ok(NAN, 360.0)).is_false()
	assert_bool(InputResolver.target_ok(36.0, INF)).is_false()


func test_register_reports_but_accepts_radius_failing_target_ok() -> void:
	var g: Rig = Rig.new()
	var id: int = g.add_target("X", Rig.T_POS, 35.0, InputResolver.Accepts.TAP, 200)
	assert_bool(id > 0).is_true()
	assert_int(g.r.reports.size()).is_equal(1)
	g.tap_at(Rig.T_POS)
	_check(g, ["pressed(X,NONE)", "tapped(X)", "became_idle"])


func test_min_supported_width_matches_field_mapping_when_present() -> void:
	assert_int(InputResolver.MIN_SUPPORTED_WIDTH_DP).is_equal(360)
	# FieldMapping comes from ADR-0003. Until it exists this checks the literal only.
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry.get("class", "") == "FieldMapping":
			var script: Script = load(str(entry.get("path", ""))) as Script
			var consts: Dictionary = script.get_script_constant_map()
			assert_int(int(consts.get("MIN_FIELD_WIDTH_DP", -1))).is_equal(InputResolver.MIN_SUPPORTED_WIDTH_DP)


func test_centre_of_unknown_id_is_nan() -> void:
	var g: Rig = Rig.new()
	var c: Vector2 = g.r.centre_of(42)
	assert_bool(is_nan(c.x) and is_nan(c.y)).is_true()
	g.add_tower()
	assert_vector(g.r.centre_of(g.t)).is_equal(Rig.T_POS)


# GestureRecord values (ADR-0008 Validation 3), hand computed.

func test_record_c07_dragged_with_wobble() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.move(0, _along(Rig.H_POS, 15.0))
	g.r.move(0, Rig.H_POS)
	g.r.release(0, Rig.H_POS)
	var rec: GestureRecord = g.r.last_gesture()
	assert_int(rec.serial).is_equal(1)
	assert_int(rec.pointer).is_equal(0)
	assert_int(rec.moves).is_equal(2)
	assert_float(rec.max_travel).is_equal(15.0)
	assert_int(rec.best_drag).is_equal(g.h)
	assert_int(rec.best_tap).is_equal(InputResolver.NONE)
	assert_vector(rec.press_pos).is_equal(Rig.H_POS)
	assert_vector(rec.drag_centre).is_equal(Rig.H_POS)
	assert_float(rec.slop).is_equal(15.0)
	assert_int(rec.drag_rule).is_equal(GestureRecord.WinRule.ONLY)
	assert_int(rec.outcome).is_equal(GestureRecord.Outcome.DRAGGED)


func test_record_c08_lost_moves() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.release(0, _along(Rig.H_POS, 15.0))
	var rec: GestureRecord = g.r.last_gesture()
	assert_int(rec.moves).is_equal(0)
	assert_float(rec.max_travel).is_equal(15.0)
	assert_int(rec.outcome).is_equal(GestureRecord.Outcome.DRAGGED_LOST_MOVES)


func test_record_c14_tapped_ground_and_drag_only() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.tap_at(Rig.T_POS)
	assert_int(g.r.last_gesture().outcome).is_equal(GestureRecord.Outcome.TAPPED)
	assert_float(g.r.last_gesture().slop).is_equal(28.0)
	assert_vector(g.r.last_gesture().tap_centre).is_equal(Rig.T_POS)
	g.tap_at(Rig.GROUND)
	var rec: GestureRecord = g.r.last_gesture()
	assert_int(rec.serial).is_equal(2)
	assert_int(rec.outcome).is_equal(GestureRecord.Outcome.GROUND_TAPPED)
	assert_int(rec.tap_rule).is_equal(GestureRecord.WinRule.NO_CANDIDATE)
	var g2: Rig = Rig.new()
	g2.add_hero()
	g2.tap_at(Rig.H_POS)
	assert_int(g2.r.last_gesture().outcome).is_equal(GestureRecord.Outcome.DRAG_WINNER_ONLY)


func test_record_c13_rolled_off() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.r.press(0, Vector2(300.0, 480.0))
	g.r.release(0, Vector2(310.0, 480.0))
	assert_int(g.r.last_gesture().outcome).is_equal(GestureRecord.Outcome.ROLLED_OFF)
	assert_float(g.r.last_gesture().max_travel).is_equal(10.0)


func test_record_c16_cancelled_keeps_last_position() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.move(0, _along(Rig.H_POS, 20.0))
	g.r.cancel()
	var rec: GestureRecord = g.r.last_gesture()
	assert_int(rec.outcome).is_equal(GestureRecord.Outcome.CANCELLED)
	assert_vector(rec.end_pos).is_equal(_along(Rig.H_POS, 20.0))
	assert_float(rec.max_travel).is_equal(20.0)


func test_record_c28_sink_flag_and_slop() -> void:
	var g: Rig = Rig.new()
	g.add_button()
	g.r.press(0, Rig.B_POS)
	var rec: GestureRecord = g.r.last_gesture()
	assert_bool(rec.tap_sink).is_true()
	assert_float(rec.slop).is_equal(15.0)
	assert_int(rec.outcome).is_equal(GestureRecord.Outcome.OPEN)


func test_record_c35_c37_replaced_and_c36_repressed_read_in_became_idle() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.add_hero()
	g.l.capture_on_idle = g.r
	g.r.press(0, Rig.H_POS)
	g.r.press(1, Rig.T_POS)
	g.r.release(1, Rig.T_POS)
	assert_int(g.l.captured.size()).is_equal(2)
	assert_int(g.l.captured[0].outcome).is_equal(GestureRecord.Outcome.REPLACED)
	assert_int(g.l.captured[0].serial).is_equal(1)
	assert_int(g.l.captured[1].outcome).is_equal(GestureRecord.Outcome.TAPPED)
	g.r.press(0, Rig.T_POS)
	g.r.press(0, Rig.T_POS)
	assert_int(g.l.captured[2].outcome).is_equal(GestureRecord.Outcome.REPRESSED)
	g.l.capture_on_idle = null
