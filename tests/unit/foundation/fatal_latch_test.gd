extends GdUnitTestSuite
## ADR-0001 Validation 1 and the latch half of Validation 5.


func test_new_latch_is_not_fatal_with_empty_cause() -> void:
	# Arrange
	var latch: FatalLatch = FatalLatch.new()

	# Assert
	assert_bool(latch.is_fatal()).is_false()
	assert_str(latch.cause()).is_equal("")


func test_one_fatal_call_sets_latch_and_cause() -> void:
	var latch: FatalLatch = FatalLatch.new()

	latch.fatal("first")

	assert_bool(latch.is_fatal()).is_true()
	assert_str(latch.cause()).is_equal("first")


func test_second_fatal_call_keeps_first_cause() -> void:
	var latch: FatalLatch = FatalLatch.new()

	latch.fatal("first")
	latch.fatal("second")

	assert_bool(latch.is_fatal()).is_true()
	assert_str(latch.cause()).is_equal("first")


func test_repeated_same_cause_is_idempotent() -> void:
	var latch: FatalLatch = FatalLatch.new()

	latch.fatal("same")
	latch.fatal("same")
	latch.fatal("same")

	assert_bool(latch.is_fatal()).is_true()
	assert_str(latch.cause()).is_equal("same")
