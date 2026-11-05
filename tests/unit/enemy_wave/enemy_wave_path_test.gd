extends GdUnitTestSuite
## PathTrack: ADR-0009 Validation 6 (make) and 7 (positions); Enemy & Wave
## Acceptance 5 and 6 (position formula), GDD "position" formula.

const WaveFixtures := preload("res://tests/helpers/wave_fixtures.gd")


func _placed(track: PathTrack, d: float) -> Enemy:
	var e: Enemy = Enemy.new(1, &"x")
	e.distance = d
	track.place(e)
	return e


func _square_track() -> PathTrack:
	return PathTrack.make(WaveFixtures.path([0, 0, 5, 0, 5, 5, 25, 5]))


func test_make_returns_null_for_an_odd_float_count() -> void:
	assert_object(PathTrack.make(WaveFixtures.path([0, 0, 1, 0, 2]))).is_null()


func test_make_returns_null_for_fewer_than_two_points() -> void:
	assert_object(PathTrack.make(WaveFixtures.path([0, 0]))).is_null()
	assert_object(PathTrack.make(PackedFloat64Array())).is_null()


func test_make_returns_null_for_a_repeated_point() -> void:
	assert_object(PathTrack.make(WaveFixtures.path([0, 0, 0, 0, 5, 5]))).is_null()
	assert_object(PathTrack.make(WaveFixtures.path([0, 0, 5, 5, 5, 5]))).is_null()


func test_make_returns_null_for_a_non_finite_coordinate() -> void:
	assert_object(PathTrack.make(WaveFixtures.path([0, 0, NAN, 1]))).is_null()
	assert_object(PathTrack.make(WaveFixtures.path([0, 0, INF, 1]))).is_null()
	assert_object(PathTrack.make(WaveFixtures.path([0, -INF, 3, 1]))).is_null()


func test_make_builds_a_track_with_the_summed_length() -> void:
	var track: PathTrack = _square_track()

	assert_object(track).is_not_null()
	assert_float(track.path_length()).is_equal(30.0)


func test_place_lands_on_corners_and_segments() -> void:
	var track: PathTrack = _square_track()

	var a: Enemy = _placed(track, 10.0)
	var b: Enemy = _placed(track, 20.0)
	var c: Enemy = _placed(track, 30.0)

	assert_float(a.pos_x).is_equal(5.0)
	assert_float(a.pos_y).is_equal(5.0)
	assert_float(b.pos_x).is_equal(15.0)
	assert_float(b.pos_y).is_equal(5.0)
	assert_float(c.pos_x).is_equal(25.0)
	assert_float(c.pos_y).is_equal(5.0)


func test_place_crosses_two_segments_in_one_step() -> void:
	var track: PathTrack = _square_track()

	var e: Enemy = _placed(track, 15.0)

	assert_float(e.pos_x).is_equal(10.0)
	assert_float(e.pos_y).is_equal(5.0)
	assert_int(e.segment).is_equal(2)


func test_place_at_or_past_the_end_is_the_last_point() -> void:
	var track: PathTrack = _square_track()

	var at_end: Enemy = _placed(track, 30.0)
	var past: Enemy = _placed(track, 999.0)

	assert_float(past.pos_x).is_equal(25.0)
	assert_float(past.pos_y).is_equal(5.0)
	assert_float(at_end.pos_x).is_equal(25.0)


func test_place_on_the_starter_stage_at_720_is_370_400() -> void:
	var track: PathTrack = PathTrack.make(WaveFixtures.path(
			[-40, 210, 430, 210, 430, 400, 110, 400, 110, 570, 270, 570, 270, 980]))

	var e: Enemy = _placed(track, 720.0)

	assert_float(track.path_length()).is_equal(1720.0)
	assert_float(e.pos_x).is_equal(370.0)
	assert_float(e.pos_y).is_equal(400.0)


func test_place_keeps_the_segment_hint_valid_going_forward() -> void:
	var track: PathTrack = _square_track()
	var e: Enemy = Enemy.new(1, &"x")

	for d: float in [1.0, 6.0, 11.0, 26.0]:
		e.distance = d
		track.place(e)
	assert_int(e.segment).is_equal(2)
	assert_float(e.pos_x).is_equal(21.0)
