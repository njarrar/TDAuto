extends GdUnitTestSuite
## ADR-0004 Validation 3 (to_ticks) and the SimTime fields.

const DENOM_60: int = 60
const DENOM_4: int = 4
const EIGHTH: float = 0.125
const TENTH: float = 0.1


func test_defaults_are_60_ticks_and_one_sixtieth_dt() -> void:
	var t: SimTime = SimTime.new()

	assert_int(t.ticks_per_second).is_equal(60)
	assert_float(t.dt).is_equal(1.0 / 60.0)


func test_custom_rate_sets_dt() -> void:
	var t: SimTime = SimTime.new(DENOM_4)

	assert_int(t.ticks_per_second).is_equal(4)
	assert_float(t.dt).is_equal(0.25)


func test_to_ticks_at_60_whole_values() -> void:
	var t: SimTime = SimTime.new(DENOM_60)

	assert_int(t.to_ticks(0.9)).is_equal(54)
	assert_int(t.to_ticks(5.0)).is_equal(300)
	assert_int(t.to_ticks(1.0 / 60.0)).is_equal(1)
	assert_int(t.to_ticks(0.0)).is_equal(0)


func test_to_ticks_eighth_steps_round_half_away_from_zero() -> void:
	var t: SimTime = SimTime.new(DENOM_60)

	assert_int(t.to_ticks(EIGHTH * 0.0)).is_equal(0)
	assert_int(t.to_ticks(EIGHTH * 1.0)).is_equal(8)
	assert_int(t.to_ticks(EIGHTH * 2.0)).is_equal(15)
	assert_int(t.to_ticks(EIGHTH * 3.0)).is_equal(23)


func test_to_ticks_tenth_member_three_is_18_by_product_and_by_sum() -> void:
	var t: SimTime = SimTime.new(DENOM_60)
	var by_sum: float = TENTH + TENTH + TENTH

	assert_int(t.to_ticks(TENTH * 3.0)).is_equal(18)
	assert_int(t.to_ticks(by_sum)).is_equal(18)


func test_to_ticks_negative_mirrors_positive() -> void:
	var t: SimTime = SimTime.new(DENOM_60)

	assert_int(t.to_ticks(0.025)).is_equal(2)
	assert_int(t.to_ticks(-0.025)).is_equal(-2)


func test_to_ticks_at_4_ticks_per_second_eighth_is_one() -> void:
	var t: SimTime = SimTime.new(DENOM_4)

	assert_int(t.to_ticks(EIGHTH)).is_equal(1)


func test_to_ticks_non_finite_gives_zero() -> void:
	var t: SimTime = SimTime.new(DENOM_60)

	assert_int(t.to_ticks(NAN)).is_equal(0)
	assert_int(t.to_ticks(INF)).is_equal(0)
	assert_int(t.to_ticks(-INF)).is_equal(0)


func test_float_countdown_by_subtraction_takes_301_ticks_regression() -> void:
	# Why integer countdowns exist: 5.0 s minus dt repeatedly overshoots by one.
	var t: SimTime = SimTime.new(DENOM_60)
	var left: float = 5.0
	var n: int = 0

	while left > 0.0 and n < 1000:
		left -= t.dt
		n += 1

	assert_int(n).is_equal(301)
