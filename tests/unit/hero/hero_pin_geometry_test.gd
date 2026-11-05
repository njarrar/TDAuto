extends GdUnitTestSuite
## Hero GDD criterion 14 (clamp_pin examples, ties, fallback, grid validity)
## and criterion 25's pure parts, for PinGeometry on the starter stage.

const Rig := preload("res://tests/unit/hero/helpers/hero_rig.gd")

const NEAR: float = 0.02


func _geometry(left_handed: bool) -> PinGeometry:
	return PinGeometry.new(StageRecord.from_dict(Rig.stage_data()), left_handed)


func _expect(point: Vector2, x: float, y: float) -> void:
	assert_float(point.x).is_equal_approx(x, NEAR)
	assert_float(point.y).is_equal_approx(y, NEAR)


func test_right_hand_examples_match_the_gdd() -> void:
	var g: PinGeometry = _geometry(false)

	_expect(g.clamp_point(492.0, 888.0, 350.0, 800.0), 395.99, 888.0)
	_expect(g.clamp_point(480.0, 850.0, 350.0, 800.0), 492.0, 767.99)
	_expect(g.clamp_point(200.0, 800.0, 350.0, 800.0), 246.01, 800.0)


func test_left_hand_example_matches_the_gdd() -> void:
	var g: PinGeometry = _geometry(true)

	_expect(g.clamp_point(84.0, 850.0, 350.0, 800.0), 144.01, 850.0)


func test_a_finger_at_a_circle_centre_goes_to_the_top_of_the_circle() -> void:
	var g: PinGeometry = _geometry(false)

	_expect(g.clamp_point(186.0, 800.0, 350.0, 800.0), 186.0, 739.99)


func test_ties_go_to_the_smaller_y_then_the_smaller_x() -> void:
	var right: PinGeometry = _geometry(false)
	_expect(right.clamp_point(456.0, 816.0, 350.0, 800.0), 456.0, 755.99)

	var data: Dictionary = Rig.stage_data()
	data["pin_exclusion"] = [{"a": [270, 480], "b": [270, 520], "radius": 60.0, "hand": "both"}]
	var one: PinGeometry = PinGeometry.new(StageRecord.from_dict(data), false)
	_expect(one.clamp_point(270.0, 500.0, 350.0, 800.0), 209.99, 500.0)


func test_shapes_covering_the_whole_rect_return_the_hold_point() -> void:
	var data: Dictionary = Rig.stage_data()
	data["pin_exclusion"] = [{"a": [270, 500], "b": [270, 500], "radius": 2000.0, "hand": "both"}]
	var g: PinGeometry = PinGeometry.new(StageRecord.from_dict(data), false)

	var point: Vector2 = g.clamp_point(100.0, 300.0, 123.0, 456.0)

	assert_float(point.x).is_equal(123.0)
	assert_float(point.y).is_equal(456.0)


func test_a_valid_finger_is_returned_unchanged() -> void:
	var g: PinGeometry = _geometry(false)

	var point: Vector2 = g.clamp_point(270.0, 480.0, 350.0, 800.0)

	assert_float(point.x).is_equal(270.0)
	assert_float(point.y).is_equal(480.0)


func test_every_finger_on_a_grid_lands_on_a_valid_pin_for_each_hand() -> void:
	for left_handed: bool in [false, true]:
		var g: PinGeometry = _geometry(left_handed)
		var bad: int = 0
		var xs: Array[float] = [540.0]
		var ys: Array[float] = [960.0]
		for ix: int in range(0, 540, 20):
			xs.append(float(ix))
		for iy: int in range(0, 960, 20):
			ys.append(float(iy))
		for fx: float in xs:
			for fy: float in ys:
				var p: Vector2 = g.clamp_point(fx, fy, 350.0, 800.0)
				if g.is_valid(p.x, p.y) != HeroSim.PinResult.OK:
					bad += 1
		assert_int(bad).is_equal(0)


func test_clamped_point_is_no_farther_than_a_brute_force_search_plus_tolerance() -> void:
	var g: PinGeometry = _geometry(false)
	var fingers: Array[Vector2] = [
		Vector2(430.0, 840.0), Vector2(470.0, 800.0), Vector2(190.0, 790.0),
		Vector2(300.0, 900.0), Vector2(520.0, 700.0)]
	for finger: Vector2 in fingers:
		var p: Vector2 = g.clamp_point(finger.x, finger.y, 350.0, 800.0)
		var got: float = (p.x - finger.x) * (p.x - finger.x) + (p.y - finger.y) * (p.y - finger.y)
		var best: float = INF
		for ix: int in range(48, 493, 2):
			for iy: int in range(174, 889, 2):
				if g.is_valid(float(ix), float(iy)) != HeroSim.PinResult.OK:
					continue
				var d2: float = (float(ix) - finger.x) * (float(ix) - finger.x) \
						+ (float(iy) - finger.y) * (float(iy) - finger.y)
				best = minf(best, d2)
		# The brute force grid is 2 apart, so it may only be worse than the clamp.
		assert_float(sqrt(got)).is_less_equal(sqrt(best) + 0.03)


func test_rect_edges_are_inside_and_just_outside_is_not() -> void:
	var g: PinGeometry = _geometry(false)

	assert_int(g.is_valid(48.0, 174.0)).is_equal(HeroSim.PinResult.OK)
	assert_int(g.is_valid(492.0, 300.0)).is_equal(HeroSim.PinResult.OK)
	assert_int(g.is_valid(47.99, 300.0)).is_equal(HeroSim.PinResult.OUT_OF_BOUNDS)
	assert_int(g.is_valid(300.0, 888.01)).is_equal(HeroSim.PinResult.OUT_OF_BOUNDS)
	assert_int(g.is_valid(300.0, 173.99)).is_equal(HeroSim.PinResult.OUT_OF_BOUNDS)
