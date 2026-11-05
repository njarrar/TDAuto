## Harness smoke suite: the smallest proof that gdUnit4 discovers, runs and
## reports a suite under tests/unit/ (ADR-0007 Decisions 1, 2 and 5).
## No class_name in tests (L-NAME-2). No file, scene or get_tree() (L-TEST-2).
extends GdUnitTestSuite

const LEFT := 2
const RIGHT := 3
const EXPECTED_SUM := 5
const CLAIMED_ERROR := "harness smoke: claimed push_error"


func test_integer_sum_returns_expected_value() -> void:
	# Arrange
	var left := LEFT
	var right := RIGHT

	# Act
	var total := left + right

	# Assert
	assert_int(total).is_equal(EXPECTED_SUM)


func test_string_join_returns_expected_text() -> void:
	# Arrange
	var parts := PackedStringArray(["tower", "riot"])

	# Act
	var joined := "_".join(parts)

	# Assert
	assert_str(joined).is_equal("tower_riot")


func test_claimed_push_error_passes() -> void:
	# Arrange
	var raise_error := func() -> void: push_error(CLAIMED_ERROR)

	# Act and Assert: the error is claimed, so with
	# gdunit4/report/godot/push_error=true it does not fail the test.
	await assert_error(raise_error).is_push_error(CLAIMED_ERROR)
