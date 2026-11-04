extends GdUnitTestSuite
## ADR-0004 Validation 4 and V4 golden values (computed in Python, matched on
## Godot 4.7.2 macOS arm64).

const GOLDEN_SEED_1: Array[int] = [270369, 67634689, 2647435461]
const GOLDEN_SEED_0: Array[int] = [1085196063, 2447379481, 2618286376]
const GOLDEN_SEED_MINUS_1: Array[int] = [253983, 4228382207, 1958451267]


func _draw3(rng: SimRng) -> Array[int]:
	var out: Array[int] = []
	for i in 3:
		out.append(rng.next_u32())
	return out


func test_seed_1_matches_golden_values() -> void:
	var rng: SimRng = SimRng.new(1)

	assert_array(_draw3(rng)).is_equal(GOLDEN_SEED_1)


func test_seed_0_uses_fallback_state_and_matches_golden_values() -> void:
	var rng: SimRng = SimRng.new(0)

	assert_array(_draw3(rng)).is_equal(GOLDEN_SEED_0)


func test_seed_minus_1_is_masked_and_matches_golden_values() -> void:
	var rng: SimRng = SimRng.new(-1)

	assert_array(_draw3(rng)).is_equal(GOLDEN_SEED_MINUS_1)


func test_draw_count_counts_each_draw() -> void:
	var rng: SimRng = SimRng.new(1)
	assert_int(rng.draw_count()).is_equal(0)

	_draw3(rng)

	assert_int(rng.draw_count()).is_equal(3)


func test_same_seed_gives_same_sequence() -> void:
	var a: SimRng = SimRng.new(12345)
	var b: SimRng = SimRng.new(12345)

	assert_array(_draw3(a)).is_equal(_draw3(b))


func test_next_below_is_modulo_of_next_u32_and_counts_one_draw() -> void:
	var rng: SimRng = SimRng.new(1)

	var v: int = rng.next_below(1000)

	assert_int(v).is_equal(270369 % 1000)
	assert_int(rng.draw_count()).is_equal(1)


func test_next_below_bad_n_returns_zero_without_drawing() -> void:
	var rng: SimRng = SimRng.new(1)

	assert_int(rng.next_below(0)).is_equal(0)
	assert_int(rng.next_below(-3)).is_equal(0)
	assert_int(rng.draw_count()).is_equal(0)
