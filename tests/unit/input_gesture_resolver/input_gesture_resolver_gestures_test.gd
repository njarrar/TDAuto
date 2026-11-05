extends GdUnitTestSuite
## Input GDD acceptance criteria 1 to 18, 31, 34 to 37 (gesture rules), headless, exact signal logs.

const Rig := preload("res://tests/unit/input_gesture_resolver/helpers/rig.gd")


func _check(g: Rig, expected: Array[String]) -> void:
	assert_str(g.joined()).is_equal(" | ".join(PackedStringArray(expected)))


func _along(p: Vector2, n: float) -> Vector2:
	return Vector2(p.x + n, p.y)


func test_c01_second_pointer_dropped_while_first_live() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.add_slot()
	g.r.press(0, Rig.T_POS)
	g.r.press(1, Rig.S_POS)
	g.r.release(1, Rig.S_POS)
	g.r.release(0, Rig.T_POS)
	g.r.move(1, _along(Rig.T_POS, 5.0))
	_check(g, ["pressed(T,NONE)", "tapped(T)", "became_idle"])


func test_c02_pressed_ground_press_is_replaced() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.r.press(0, Rig.GROUND)
	g.r.press(1, Rig.T_POS)
	g.r.release(1, Rig.T_POS)
	g.r.release(0, Rig.GROUND)
	_check(g, ["pressed(NONE,NONE)", "became_idle", "pressed(T,NONE)", "tapped(T)", "became_idle"])


func test_c03_dead_ground_press_is_replaced() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.r.press(0, Rig.GROUND)
	g.r.move(0, _along(Rig.GROUND, 30.0))
	g.r.press(1, Rig.T_POS)
	g.r.release(1, Rig.T_POS)
	_check(g, ["pressed(NONE,NONE)", "became_idle", "pressed(T,NONE)", "tapped(T)", "became_idle"])


func test_c04_live_drag_is_not_replaced() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.move(0, _along(Rig.H_POS, 20.0))
	g.r.press(1, Rig.T_POS)
	g.r.release(1, Rig.T_POS)
	g.r.release(0, _along(Rig.H_POS, 20.0))
	_check(g, ["pressed(NONE,H)", "drag_started(H)", "drag_ended(H)", "became_idle"])


func test_c05_lost_release_repress_cancels_drag() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.move(0, _along(Rig.H_POS, 20.0))
	g.r.press(0, Rig.T_POS)
	_check(g, ["pressed(NONE,H)", "drag_started(H)", "drag_cancelled(H)", "became_idle", "pressed(T,NONE)"])


func test_c06_winners_are_frozen() -> void:
	var g: Rig = Rig.new()
	g.add_slot()
	g.add_hero(Rig.S_POS)
	g.r.press(0, Rig.S_POS)
	g.r.set_centre(g.h, Vector2.ZERO)
	g.r.release(0, Rig.S_POS)
	_check(g, ["pressed(S,H)", "tapped(S)", "became_idle"])


func test_c07_drag_is_sticky() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.move(0, _along(Rig.H_POS, 15.0))
	g.r.move(0, Rig.H_POS)
	g.r.release(0, Rig.H_POS)
	_check(g, ["pressed(NONE,H)", "drag_started(H)", "drag_moved(H)", "drag_ended(H)", "became_idle"])


func test_c08_lost_moves_with_drag_winner() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.release(0, _along(Rig.H_POS, 15.0))
	_check(g, ["pressed(NONE,H)", "drag_started(H)", "drag_ended(H)", "became_idle"])


func test_c09_lost_moves_with_tap_winner_is_no_tap() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.r.press(0, Rig.T_POS)
	g.r.release(0, _along(Rig.T_POS, 28.0))
	_check(g, ["pressed(T,NONE)", "became_idle"])


func test_c10_tap_slop_under_and_at() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.r.press(0, Rig.T_POS)
	g.r.move(0, _along(Rig.T_POS, 20.0))
	g.r.release(0, _along(Rig.T_POS, 20.0))
	_check(g, ["pressed(T,NONE)", "tapped(T)", "became_idle"])
	var g2: Rig = Rig.new()
	g2.add_tower()
	g2.r.press(0, Rig.T_POS)
	g2.r.move(0, _along(Rig.T_POS, 28.0))
	g2.r.release(0, _along(Rig.T_POS, 28.0))
	_check(g2, ["pressed(T,NONE)", "became_idle"])


func test_c11_slop_is_per_press() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.move(0, _along(Rig.H_POS, 15.0))
	g.r.release(0, _along(Rig.H_POS, 15.0))
	_check(g, ["pressed(NONE,H)", "drag_started(H)", "drag_ended(H)", "became_idle"])
	var g2: Rig = Rig.new()
	g2.add_tower()
	g2.r.press(0, Rig.T_POS)
	g2.r.move(0, _along(Rig.T_POS, 15.0))
	g2.r.release(0, _along(Rig.T_POS, 15.0))
	_check(g2, ["pressed(T,NONE)", "tapped(T)", "became_idle"])


func test_c12_no_fall_through() -> void:
	var g: Rig = Rig.new()
	g.add_slot()
	g.r.press(0, Rig.S_POS)
	g.r.move(0, _along(Rig.S_POS, 28.0))
	g.r.move(0, _along(Rig.S_POS, 30.0))
	g.r.release(0, _along(Rig.S_POS, 30.0))
	_check(g, ["pressed(S,NONE)", "became_idle"])


func test_c13_release_off_the_disc() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	var start: Vector2 = Vector2(300.0, 480.0)
	g.r.press(0, start)
	g.r.move(0, Vector2(310.0, 480.0))
	g.r.release(0, Vector2(310.0, 480.0))
	_check(g, ["pressed(T,NONE)", "became_idle"])


func test_c14_release_in_place_three_cases() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.tap_at(Rig.T_POS)
	_check(g, ["pressed(T,NONE)", "tapped(T)", "became_idle"])
	var g2: Rig = Rig.new()
	g2.tap_at(Rig.GROUND)
	_check(g2, ["pressed(NONE,NONE)", "ground_tapped", "became_idle"])
	var g3: Rig = Rig.new()
	g3.add_hero()
	g3.tap_at(Rig.H_POS)
	_check(g3, ["pressed(NONE,H)", "became_idle"])


func test_c15_drag_payload_positions_exact() -> void:
	var g: Rig = Rig.new()
	g.add_slot()
	g.add_hero(Rig.S_POS)
	var p0: Vector2 = Rig.S_POS
	var p1: Vector2 = Vector2(298.0, 600.0)
	var p2: Vector2 = Vector2(310.0, 610.0)
	var p3: Vector2 = Vector2(320.0, 620.0)
	var p4: Vector2 = Vector2(330.0, 630.0)
	g.r.press(0, p0)
	g.r.move(0, p1)
	g.r.move(0, p2)
	g.r.move(0, p3)
	g.r.release(0, p4)
	_check(g, ["pressed(S,H)", "drag_started(H)", "drag_moved(H)", "drag_moved(H)", "drag_ended(H)", "became_idle"])
	assert_array(Array(g.l.pos_log[0])).is_equal([p0])
	assert_array(Array(g.l.pos_log[1])).is_equal([p0, p1])
	assert_array(Array(g.l.pos_log[2])).is_equal([p0, p2])
	assert_array(Array(g.l.pos_log[3])).is_equal([p0, p3])
	assert_array(Array(g.l.pos_log[4])).is_equal([p0, p4])


func test_c16_cancel_per_state() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.move(0, _along(Rig.H_POS, 20.0))
	g.r.cancel()
	g.r.release(0, _along(Rig.H_POS, 20.0))
	_check(g, ["pressed(NONE,H)", "drag_started(H)", "drag_cancelled(H)", "became_idle"])
	var g2: Rig = Rig.new()
	g2.add_tower()
	g2.r.press(0, Rig.T_POS)
	g2.r.cancel()
	g2.r.release(0, Rig.T_POS)
	_check(g2, ["pressed(T,NONE)", "became_idle"])
	var g3: Rig = Rig.new()
	g3.r.press(0, Rig.GROUND)
	g3.r.move(0, _along(Rig.GROUND, 30.0))
	g3.r.cancel()
	_check(g3, ["pressed(NONE,NONE)", "became_idle"])
	var g4: Rig = Rig.new()
	g4.r.cancel()
	_check(g4, [])


func test_c17_per_pointer_cancel() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.move(0, _along(Rig.H_POS, 20.0))
	g.r.cancel_pointer(1)
	g.r.move(0, _along(Rig.H_POS, 25.0))
	g.r.release(0, _along(Rig.H_POS, 25.0))
	_check(g, ["pressed(NONE,H)", "drag_started(H)", "drag_moved(H)", "drag_ended(H)", "became_idle"])
	var g2: Rig = Rig.new()
	g2.add_hero()
	g2.r.press(0, Rig.H_POS)
	g2.r.move(0, _along(Rig.H_POS, 20.0))
	g2.r.cancel_pointer(0)
	g2.r.release(0, _along(Rig.H_POS, 20.0))
	_check(g2, ["pressed(NONE,H)", "drag_started(H)", "drag_cancelled(H)", "became_idle"])


func test_c18_two_taps_in_a_row() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.tap_at(Rig.T_POS)
	g.tap_at(Rig.T_POS)
	_check(g, ["pressed(T,NONE)", "tapped(T)", "became_idle", "pressed(T,NONE)", "tapped(T)", "became_idle"])


func test_c31_is_drag_boundary() -> void:
	var g: Rig = Rig.new()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.move(0, Vector2(109.0, 111.0))
	_check(g, ["pressed(NONE,H)"])
	g.r.move(0, Vector2(109.0, 112.0))
	_check(g, ["pressed(NONE,H)", "drag_started(H)"])


func test_c34_hero_parked_on_tower() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.add_hero(Rig.T_POS)
	g.r.press(0, Rig.T_POS)
	g.r.move(0, _along(Rig.T_POS, 16.0))
	g.r.release(0, _along(Rig.T_POS, 16.0))
	_check(g, ["pressed(T,H)", "tapped(T)", "became_idle"])
	var g2: Rig = Rig.new()
	g2.add_tower()
	g2.add_hero(Rig.T_POS)
	g2.r.press(0, Rig.T_POS)
	g2.r.move(0, _along(Rig.T_POS, 28.0))
	g2.r.release(0, _along(Rig.T_POS, 28.0))
	_check(g2, ["pressed(T,H)", "drag_started(H)", "drag_ended(H)", "became_idle"])
	var g3: Rig = Rig.new()
	g3.add_hero()
	g3.r.press(0, Rig.H_POS)
	g3.r.move(0, _along(Rig.H_POS, 15.0))
	g3.r.release(0, _along(Rig.H_POS, 15.0))
	_check(g3, ["pressed(NONE,H)", "drag_started(H)", "drag_ended(H)", "became_idle"])


func test_c35_replacement_cases() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.add_hero()
	g.r.press(0, Rig.H_POS)
	g.r.press(1, Rig.T_POS)
	g.r.release(1, Rig.T_POS)
	_check(g, ["pressed(NONE,H)", "became_idle", "pressed(T,NONE)", "tapped(T)", "became_idle"])
	var g2: Rig = Rig.new()
	g2.add_tower()
	g2.add_button()
	g2.r.press(0, Rig.B_POS)
	g2.r.press(1, Rig.T_POS)
	g2.r.release(1, Rig.T_POS)
	_check(g2, ["pressed(Z,B)", "became_idle", "pressed(T,NONE)", "tapped(T)", "became_idle"])
	var g3: Rig = Rig.new()
	g3.add_tower()
	g3.add_slot()
	g3.r.press(0, Rig.T_POS)
	g3.r.press(1, Rig.S_POS)
	g3.r.release(1, Rig.S_POS)
	_check(g3, ["pressed(T,NONE)"])


func test_c36_dead_and_active_repress() -> void:
	var g: Rig = Rig.new()
	g.add_tower()
	g.add_slot()
	g.r.press(0, Rig.T_POS)
	g.r.move(0, _along(Rig.T_POS, 28.0))
	g.r.move(0, _along(Rig.T_POS, 40.0))
	g.r.press(1, Rig.S_POS)
	_check(g, ["pressed(T,NONE)"])
	g.r.press(0, Rig.S_POS)
	_check(g, ["pressed(T,NONE)", "became_idle", "pressed(S,NONE)"])
	var g2: Rig = Rig.new()
	g2.add_tower()
	g2.r.press(0, Rig.T_POS)
	g2.r.cancel_pointer(0)
	_check(g2, ["pressed(T,NONE)", "became_idle"])


func test_c37_dead_sink_only_press_is_replaceable() -> void:
	var g: Rig = Rig.new()
	g.add_arc_disc()
	g.add_backdrop()
	g.r.press(0, Rig.GROUND)
	g.r.move(0, _along(Rig.GROUND, 20.0))
	var on_disc: Vector2 = Vector2(270.0, 560.0)
	g.r.press(1, on_disc)
	g.r.release(1, on_disc)
	_check(g, ["pressed(K,NONE)", "became_idle", "pressed(A,NONE)", "tapped(A)", "became_idle"])
